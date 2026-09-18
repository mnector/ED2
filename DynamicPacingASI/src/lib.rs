use std::env;
use std::thread;
use std::time::Duration;
use std::fs::OpenOptions;
use std::io::Write;
use winapi::shared::minwindef::{BOOL, DWORD, HINSTANCE, LPVOID, TRUE};
use winapi::um::winnt::{DLL_PROCESS_ATTACH, PAGE_EXECUTE_READWRITE};
use winapi::um::memoryapi::VirtualProtect;
use winapi::um::psapi::{EnumProcessModules, GetModuleFileNameExA};
use winapi::um::processthreadsapi::GetCurrentProcess;
use winapi::um::libloaderapi::GetModuleHandleA;

unsafe fn patch_memory(addr: *mut u8, bytes: &[u8]) {
    let mut old_protect = 0;
    VirtualProtect(addr as *mut _, bytes.len(), PAGE_EXECUTE_READWRITE, &mut old_protect);
    std::ptr::copy_nonoverlapping(bytes.as_ptr(), addr, bytes.len());
    VirtualProtect(addr as *mut _, bytes.len(), old_protect, &mut old_protect);
}

fn log_msg(msg: &str) {
    let log_path = env::var("ENY_LOG_PATH")
        .unwrap_or_else(|_| "envy_asi.log".to_string());
    
    if let Ok(mut file) = OpenOptions::new().create(true).append(true).open(&log_path) {
        let _ = writeln!(file, "{}", msg);
    }
}

fn is_system_path(name: &str) -> bool {
    name.contains("\\windows\\") || name.contains("\\system32\\") || name.contains("\\syswow64\\")
}

fn get_optiscaler_module() -> Option<(*const u8, String)> {
    unsafe {
        let process = GetCurrentProcess();
        let mut modules = [std::ptr::null_mut(); 1024];
        let mut cb_needed = 0;
        
        if EnumProcessModules(process, modules.as_mut_ptr(), std::mem::size_of_val(&modules) as u32, &mut cb_needed) != 0 {
            let count = (cb_needed as usize) / std::mem::size_of::<HINSTANCE>();
            for i in 0..count {
                let mut name_buf = [0i8; 260];
                if GetModuleFileNameExA(process, modules[i], name_buf.as_mut_ptr(), name_buf.len() as u32) > 0 {
                    let name = std::ffi::CStr::from_ptr(name_buf.as_ptr()).to_string_lossy().to_lowercase();
                    if !is_system_path(&name) {
                        if name.ends_with("version.dll") || name.ends_with("dxgi.dll") || 
                           name.ends_with("optiscaler.dll") || name.ends_with("winmm.dll") || 
                           name.ends_with("wininet.dll") || name.ends_with("d3d12.dll") {
                            return Some((modules[i] as *const u8, name));
                        }
                    }
                }
            }
        }
    }
    None
}

/// ===============================================================
/// v3.0 STRATEGY: "Kill the messenger, not the message"
/// 
/// Previous attempts NOPd the CONDITIONAL JUMPS leading to the
/// error routine at RVA 0xF23B. But we missed a third path
/// (unconditional JMP at 0xF138), and the cap/budget variables
/// kept getting reset by code we didn't patch.
///
/// NEW APPROACH: Instead of chasing every possible jump INTO the
/// error routine, we NOP the TWO DAMAGE INSTRUCTIONS inside the
/// error routine ITSELF. This makes it HARMLESS regardless of how
/// many code paths reach it.
///
/// The two kill-switch instructions:
///   0xF28A: 44 87 25 CD 7A 06 00  XCHG [timeout_count], R12D
///   0xF293: B8 FF FF FF FF        MOV EAX, 0xFFFFFFFF  
///   0xF298: 87 05 B6 7A 06 00     XCHG [keep_input_flag], EAX
///
/// These write the "current input kept" signal that tells the
/// renderer to DISCARD the neural frame and show raw pixels.
/// By NOPing them, the error routine still runs, still logs,
/// but NEVER discards a frame.
///
/// Additionally we patch:
///   0xF121: Budget halving XCHG (in the timeout handler)
///   0x3BC1: Budget XCHG (in another code path)
///   0xF0BF: Cap recalculator XCHG  
///   0xF1B7: Budget reducer XCHG
///   0xF138: Unconditional JMP to error routine (make it skip)
///   0x10568: Init cap value (change from 1.5M to 2B)
/// ===============================================================
unsafe fn patch_pass_module(base: *const u8, name: &str) {
    let mut count = 0u32;

    // ===== THE CORE FIX: NOP the damage instructions in error routine =====

    // 1. Error routine kill-switch #1: XCHG [timeout_count], R12D
    // RVA 0xF28A: 44 87 25 CD 7A 06 00 (7 bytes) -> 7 NOPs
    let ks1 = (base as usize + 0xF28A) as *mut u8;
    if *ks1 == 0x44 && *ks1.add(1) == 0x87 && *ks1.add(2) == 0x25 {
        patch_memory(ks1, &[0x90; 7]);
        log_msg(&format!("[{}] Kill-switch #1 NOP'd: XCHG timeout_count at RVA 0xF28A", name));
        count += 1;
    } else if *ks1 == 0x90 { count += 1; }

    // 2. Error routine kill-switch #2: MOV EAX,-1 + XCHG [keep_input], EAX
    // RVA 0xF293: B8 FF FF FF FF (5 bytes) -> 5 NOPs
    // RVA 0xF298: 87 05 B6 7A 06 00 (6 bytes) -> 6 NOPs
    // Total: 11 bytes of NOPs
    let ks2 = (base as usize + 0xF293) as *mut u8;
    if *ks2 == 0xB8 && *ks2.add(1) == 0xFF && *ks2.add(2) == 0xFF {
        patch_memory(ks2, &[0x90; 11]);
        log_msg(&format!("[{}] Kill-switch #2 NOP'd: MOV+XCHG keep_input at RVA 0xF293-0xF29D", name));
        count += 1;
    } else if *ks2 == 0x90 { count += 1; }

    // ===== AUXILIARY PATCHES: prevent cap/budget degradation =====

    // 3. Cap recalculator XCHG at RVA 0xF0BF: 87 05 xx xx xx xx -> 6 NOPs
    let cap_recalc = (base as usize + 0xF0BF) as *mut u8;
    if *cap_recalc == 0x87 && *cap_recalc.add(1) == 0x05 {
        patch_memory(cap_recalc, &[0x90; 6]);
        log_msg(&format!("[{}] Cap recalculator NOP'd at RVA 0xF0BF", name));
        count += 1;
    } else if *cap_recalc == 0x90 { count += 1; }

    // 4. Budget reducer XCHG at RVA 0xF1B7: 87 15 xx xx xx xx -> 6 NOPs
    let budget_reducer = (base as usize + 0xF1B7) as *mut u8;
    if *budget_reducer == 0x87 && *budget_reducer.add(1) == 0x15 {
        patch_memory(budget_reducer, &[0x90; 6]);
        log_msg(&format!("[{}] Budget reducer NOP'd at RVA 0xF1B7", name));
        count += 1;
    } else if *budget_reducer == 0x90 { count += 1; }

    // 5. Budget halver XCHG at RVA 0xF121: 87 05 xx xx xx xx -> 6 NOPs
    let budget_halver = (base as usize + 0xF121) as *mut u8;
    if *budget_halver == 0x87 && *budget_halver.add(1) == 0x05 {
        patch_memory(budget_halver, &[0x90; 6]);
        log_msg(&format!("[{}] Budget halver NOP'd at RVA 0xF121", name));
        count += 1;
    } else if *budget_halver == 0x90 { count += 1; }

    // 6. Budget XCHG at RVA 0x3BC1: 87 05 xx xx xx xx -> 6 NOPs
    let budget_other = (base as usize + 0x3BC1) as *mut u8;
    if *budget_other == 0x87 && *budget_other.add(1) == 0x05 {
        patch_memory(budget_other, &[0x90; 6]);
        log_msg(&format!("[{}] Budget init XCHG NOP'd at RVA 0x3BC1", name));
        count += 1;
    } else if *budget_other == 0x90 { count += 1; }

    // 7. Unconditional JMP at RVA 0xF138: E9 FE 00 00 00 -> 5 NOPs
    //    This was the MISSED third path into the error routine!
    let jmp_err = (base as usize + 0xF138) as *mut u8;
    if *jmp_err == 0xE9 {
        patch_memory(jmp_err, &[0x90; 5]);
        log_msg(&format!("[{}] Unconditional JMP to error routine NOP'd at RVA 0xF138", name));
        count += 1;
    } else if *jmp_err == 0x90 { count += 1; }

    // 8. Host watchdog JGE at RVA 0xF0DF: 0F 8D -> 6 NOPs
    let hw_jge = (base as usize + 0xF0DF) as *mut u8;
    if *hw_jge == 0x0F && *hw_jge.add(1) == 0x8D {
        patch_memory(hw_jge, &[0x90; 6]);
        log_msg(&format!("[{}] Host watchdog JGE NOP'd at RVA 0xF0DF", name));
        count += 1;
    } else if *hw_jge == 0x90 { count += 1; }

    // 9. Iteration cap JL at RVA 0xF0F7: 0F 8C -> 6 NOPs
    let it_jl = (base as usize + 0xF0F7) as *mut u8;
    if *it_jl == 0x0F && *it_jl.add(1) == 0x8C {
        patch_memory(it_jl, &[0x90; 6]);
        log_msg(&format!("[{}] Iteration cap JL NOP'd at RVA 0xF0F7", name));
        count += 1;
    } else if *it_jl == 0x90 { count += 1; }

    // 10. Init cap at RVA 0x10568: C7 05 D2 66 06 00 [60 E3 16 00] -> change imm32 to 2B
    //     MOV [rip+0x666D2], 1500000 -> MOV [rip+0x666D2], 2000000000
    let init_cap = (base as usize + 0x10568) as *mut u8;
    if *init_cap == 0xC7 && *init_cap.add(1) == 0x05 {
        // Overwrite only the 4-byte immediate at offset +6
        let imm_ptr = (base as usize + 0x10568 + 6) as *mut u32;
        let mut old_p = 0;
        if VirtualProtect(imm_ptr as *mut _, 4, PAGE_EXECUTE_READWRITE, &mut old_p) != 0 {
            *imm_ptr = 2_000_000_000;
            VirtualProtect(imm_ptr as *mut _, 4, old_p, &mut old_p);
            log_msg(&format!("[{}] Init cap patched to 2B at RVA 0x10568", name));
            count += 1;
        }
    } else { count += 1; }

    // 11. Direct Live RAM Clamping (belt and suspenders)
    let ram_cap_ptr = (base as usize + 0x76C44) as *mut u32;
    let ram_budget_ptr = (base as usize + 0x76C54) as *mut u32;
    let mut old_protect = 0;
    if VirtualProtect(ram_cap_ptr as *mut _, 32, PAGE_EXECUTE_READWRITE, &mut old_protect) != 0 {
        *ram_cap_ptr = 2_000_000_000;
        *ram_budget_ptr = 2000;
        VirtualProtect(ram_cap_ptr as *mut _, 32, old_protect, &mut old_protect);
    }

    log_msg(&format!("[{}] v3.0 Total Immunity: {}/10 patches applied, RAM clamped.", name, count));
}

unsafe fn patch_optiscaler(base: *const u8, name: &str) -> bool {
    let mut patched_a = false;
    let mut patched_b = false;
    let mut patched_c = false;

    // Fast check at known RVAs first
    let a_ptr = (base as usize + 0x14587) as *mut u8;
    if *a_ptr == 0x48 && *a_ptr.add(1) == 0x83 && *a_ptr.add(2) == 0x81 {
        patch_memory(a_ptr, &[0x90; 8]);
        patched_a = true;
        log_msg(&format!("Patch A applied directly at RVA 0x14587 for {}", name));
    } else if *a_ptr == 0x90 && *a_ptr.add(1) == 0x90 {
        patched_a = true;
    }

    let b_ptr = (base as usize + 0x19442) as *mut u8;
    if *b_ptr == 0x0F && *b_ptr.add(1) == 0x84 {
        patch_memory(b_ptr, &[0xE9, 0xD3, 0x00, 0x00, 0x00, 0x90]);
        patched_b = true;
        log_msg(&format!("Patch B applied directly at RVA 0x19442 for {}", name));
    } else if *b_ptr == 0xE9 {
        patched_b = true;
    }

    let c_ptr = (base as usize + 0x14750) as *mut u8;
    if *c_ptr == 0x0F && *c_ptr.add(1) == 0x84 {
        patch_memory(c_ptr, &[0xE9, 0xD0, 0x00, 0x00, 0x00, 0x90]);
        patched_c = true;
        log_msg(&format!("Patch C applied directly at RVA 0x14750 for {}", name));
    } else if *c_ptr == 0xE9 {
        patched_c = true;
    }

    if patched_a && patched_b && patched_c {
        return true;
    }

    // Fallback scan up to 500 KB (.text section) if build differs
    for i in 0..500_000 {
        let ptr = base.add(i);
        if !patched_a && *ptr == 0x48 && *ptr.add(1) == 0x83 && *ptr.add(2) == 0xF8 && *ptr.add(3) == 0x10 && *ptr.add(4) == 0x73 && *ptr.add(5) == 0x1B {
            let error_counter_ptr = ptr.add(0x36) as *mut u8;
            if *error_counter_ptr == 0x48 && *error_counter_ptr.add(1) == 0x83 && *error_counter_ptr.add(2) == 0x81 {
                patch_memory(error_counter_ptr, &[0x90; 8]);
                patched_a = true;
                log_msg(&format!("Patch A found by scan at offset {:#x}", i + 0x36));
            }
        }
        if !patched_b && *ptr == 0x45 && *ptr.add(1) == 0x84 && *ptr.add(2) == 0xC9 &&
           *ptr.add(3) == 0x0F && *ptr.add(4) == 0x84 && 
           *ptr.add(5) == 0xD2 && *ptr.add(6) == 0x00 && *ptr.add(7) == 0x00 && *ptr.add(8) == 0x00 {
            let patch_addr = ptr.add(3) as *mut u8;
            if *patch_addr == 0x0F {
                patch_memory(patch_addr, &[0xE9, 0xD3, 0x00, 0x00, 0x00, 0x90]);
                patched_b = true;
                log_msg(&format!("Patch B found by scan at offset {:#x}", i + 3));
            }
        }
        if !patched_c && *ptr == 0xB1 && *ptr.add(1) == 0x01 && *ptr.add(2) == 0x48 && *ptr.add(3) == 0x8B &&
           *ptr.add(4) == 0x06 && *ptr.add(5) == 0x44 && *ptr.add(12) == 0x84 && *ptr.add(13) == 0xC9 && 
           *ptr.add(14) == 0x0F && *ptr.add(15) == 0x84 {
            let patch_addr = ptr.add(14) as *mut u8; 
            if *patch_addr == 0x0F {
                patch_memory(patch_addr, &[0xE9, 0xD0, 0x00, 0x00, 0x00, 0x90]);
                patched_c = true;
                log_msg(&format!("Patch C found by scan at offset {:#x}", i + 14));
            }
        }
        if patched_a && patched_b && patched_c {
            return true;
        }
    }
    false
}

fn immortal_watchdog_loop() {
    let gpu_gen = env::var("ENY_GPU_GEN")
        .unwrap_or_else(|_| "unknown".to_string());
    log_msg("Envy Watchdog v3.0.0 (Absolute Zero: Error routine neutralized at source) started");
    log_msg(&format!("Detected GPU generation: {}", gpu_gen));

    let mut optiscaler_done = false;
    let mut pass1_done = false;
    let mut pass2_done = false;
    let mut pass3_done = false;

    loop {
        // 1. OptiScaler
        if !optiscaler_done {
            if let Some((base, name)) = get_optiscaler_module() {
                unsafe {
                    if patch_optiscaler(base, &name) {
                        optiscaler_done = true;
                        log_msg(&format!("OptiScaler ({}) fully neutralized.", name));
                    }
                }
            }
        }

        // 2. AMD passes
        unsafe {
            let modules: [(&[u8], &mut bool); 3] = [
                (b"dlssnr_amd_pass1.dll\0", &mut pass1_done),
                (b"dlssnr_amd_pass2.dll\0", &mut pass2_done),
                (b"dlssnr_amd_pass3.dll\0", &mut pass3_done),
            ];

            for (mod_name, done_ref) in modules {
                let handle = GetModuleHandleA(mod_name.as_ptr() as *const i8);
                if !handle.is_null() {
                    let base = handle as *const u8;
                    let mod_str = std::ffi::CStr::from_ptr(mod_name.as_ptr() as *const i8).to_string_lossy();
                    
                    if !*done_ref {
                        log_msg(&format!("=== Neutralizing {} (v3.0 Absolute Zero) ===", mod_str));
                        patch_pass_module(base, &mod_str);
                        *done_ref = true;
                    }

                    // Keep RAM clamp active every cycle (belt and suspenders)
                    let ram_cap = (base as usize + 0x76C44) as *mut u32;
                    let ram_budget = (base as usize + 0x76C54) as *mut u32;
                    let mut old_p = 0;
                    if VirtualProtect(ram_cap as *mut _, 32, PAGE_EXECUTE_READWRITE, &mut old_p) != 0 {
                        *ram_cap = 2_000_000_000;
                        *ram_budget = 2000;
                        VirtualProtect(ram_cap as *mut _, 32, old_p, &mut old_p);
                    }
                }
            }
        }

        thread::sleep(Duration::from_millis(250));
    }
}

#[no_mangle]
#[allow(non_snake_case)]
pub extern "system" fn DllMain(_module: HINSTANCE, call_reason: DWORD, _reserved: LPVOID) -> BOOL {
    if call_reason == DLL_PROCESS_ATTACH {
        thread::spawn(move || { immortal_watchdog_loop(); });
    }
    TRUE
}

#[no_mangle]
#[allow(non_snake_case)]
pub extern "C" fn InitializeASI() {}
