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

unsafe fn patch_pass_module(base: *const u8, name: &str) {
    let mut count = 0u32;

    // ===== THE CORE FIX (v4.0 Absolute Zero) =====

    // 1. Error routine kill-switch #1: XCHG [timeout_count], R12D
    // RVA 0xF28C (was mistakenly 0xF28A before): 44 87 25 CD 7A 06 00 (7 bytes) -> 7 NOPs
    let ks1 = (base as usize + 0xF28C) as *mut u8;
    if *ks1 == 0x44 && *ks1.add(1) == 0x87 && *ks1.add(2) == 0x25 {
        patch_memory(ks1, &[0x90; 7]);
        log_msg(&format!("[{}] Kill-switch #1 NOP'd: XCHG timeout_count at RVA 0xF28C", name));
        count += 1;
    } else if *ks1 == 0x90 { count += 1; }

    // 2. Error routine kill-switch #2: MOV EAX,-1 + XCHG [keep_input], EAX
    // RVA 0xF293: B8 FF FF FF FF (MOV EAX, -1) -> Change to B8 00 00 00 00 (MOV EAX, 0)
    // This actively FORCES the renderer to accept the neural frame, overriding the timeout!
    let ks2 = (base as usize + 0xF293) as *mut u8;
    if *ks2 == 0xB8 && *ks2.add(1) == 0xFF && *ks2.add(2) == 0xFF {
        patch_memory(ks2, &[0xB8, 0x00, 0x00, 0x00, 0x00]);
        log_msg(&format!("[{}] Kill-switch #2 OVERRIDDEN: MOV EAX, 0 at RVA 0xF293", name));
        count += 1;
    } else if *ks2 == 0xB8 && *ks2.add(1) == 0x00 { count += 1; }

    // ===== AUXILIARY PATCHES: prevent cap/budget degradation =====

    let cap_recalc = (base as usize + 0xF0BF) as *mut u8;
    if *cap_recalc == 0x87 && *cap_recalc.add(1) == 0x05 {
        patch_memory(cap_recalc, &[0x90; 6]);
        count += 1;
    } else if *cap_recalc == 0x90 { count += 1; }

    let budget_reducer = (base as usize + 0xF1B7) as *mut u8;
    if *budget_reducer == 0x87 && *budget_reducer.add(1) == 0x15 {
        patch_memory(budget_reducer, &[0x90; 6]);
        count += 1;
    } else if *budget_reducer == 0x90 { count += 1; }

    let budget_halver = (base as usize + 0xF121) as *mut u8;
    if *budget_halver == 0x87 && *budget_halver.add(1) == 0x05 {
        patch_memory(budget_halver, &[0x90; 6]);
        count += 1;
    } else if *budget_halver == 0x90 { count += 1; }

    let budget_other = (base as usize + 0x3BC1) as *mut u8;
    if *budget_other == 0x87 && *budget_other.add(1) == 0x05 {
        patch_memory(budget_other, &[0x90; 6]);
        count += 1;
    } else if *budget_other == 0x90 { count += 1; }

    let jmp_err = (base as usize + 0xF138) as *mut u8;
    if *jmp_err == 0xE9 {
        patch_memory(jmp_err, &[0x90; 5]);
        count += 1;
    } else if *jmp_err == 0x90 { count += 1; }

    let hw_jge = (base as usize + 0xF0DF) as *mut u8;
    if *hw_jge == 0x0F && *hw_jge.add(1) == 0x8D {
        patch_memory(hw_jge, &[0x90; 6]);
        count += 1;
    } else if *hw_jge == 0x90 { count += 1; }

    let it_jl = (base as usize + 0xF0F7) as *mut u8;
    if *it_jl == 0x0F && *it_jl.add(1) == 0x8C {
        patch_memory(it_jl, &[0x90; 6]);
        count += 1;
    } else if *it_jl == 0x90 { count += 1; }

    let init_cap = (base as usize + 0x10568) as *mut u8;
    if *init_cap == 0xC7 && *init_cap.add(1) == 0x05 {
        let imm_ptr = (base as usize + 0x10568 + 6) as *mut u32;
        let mut old_p = 0;
        if VirtualProtect(imm_ptr as *mut _, 4, PAGE_EXECUTE_READWRITE, &mut old_p) != 0 {
            *imm_ptr = 2_000_000_000;
            VirtualProtect(imm_ptr as *mut _, 4, old_p, &mut old_p);
            count += 1;
        }
    } else { count += 1; }

    let ram_cap_ptr = (base as usize + 0x76C44) as *mut u32;
    let ram_budget_ptr = (base as usize + 0x76C54) as *mut u32;
    let mut old_protect = 0;
    if VirtualProtect(ram_cap_ptr as *mut _, 32, PAGE_EXECUTE_READWRITE, &mut old_protect) != 0 {
        *ram_cap_ptr = 2_000_000_000;
        *ram_budget_ptr = 2000;
        VirtualProtect(ram_cap_ptr as *mut _, 32, old_protect, &mut old_protect);
    }

    log_msg(&format!("[{}] v4.0 Total Immunity: {}/10 patches applied.", name, count));
}

unsafe fn patch_optiscaler(base: *const u8, name: &str) -> bool {
    let mut patched = 0;

    // OptiScaler AMD skipped 16ms bypass
    // At 0x14585: 73 6A (JAE +0x6A) -> Change to EB 6A (JMP +0x6A)
    // This forces OptiScaler to believe the GPU work succeeded, even if it took >16ms!
    let d_ptr = (base as usize + 0x14585) as *mut u8;
    if *d_ptr == 0x73 && *d_ptr.add(1) == 0x6A {
        patch_memory(d_ptr, &[0xEB, 0x6A]);
        log_msg(&format!("Patch D (16ms skip bypass) applied directly at RVA 0x14585 for {}", name));
        patched += 1;
    } else if *d_ptr == 0xEB && *d_ptr.add(1) == 0x6A {
        patched += 1;
    }

    let a_ptr = (base as usize + 0x14587) as *mut u8;
    if *a_ptr == 0x48 && *a_ptr.add(1) == 0x83 && *a_ptr.add(2) == 0x81 {
        patch_memory(a_ptr, &[0x90; 8]);
        log_msg(&format!("Patch A applied directly at RVA 0x14587 for {}", name));
        patched += 1;
    } else if *a_ptr == 0x90 && *a_ptr.add(1) == 0x90 {
        patched += 1;
    }

    let b_ptr = (base as usize + 0x19442) as *mut u8;
    if *b_ptr == 0x0F && *b_ptr.add(1) == 0x84 {
        patch_memory(b_ptr, &[0xE9, 0xD3, 0x00, 0x00, 0x00, 0x90]);
        log_msg(&format!("Patch B applied directly at RVA 0x19442 for {}", name));
        patched += 1;
    } else if *b_ptr == 0xE9 {
        patched += 1;
    }

    let c_ptr = (base as usize + 0x14750) as *mut u8;
    if *c_ptr == 0x0F && *c_ptr.add(1) == 0x84 {
        patch_memory(c_ptr, &[0xE9, 0xD0, 0x00, 0x00, 0x00, 0x90]);
        log_msg(&format!("Patch C applied directly at RVA 0x14750 for {}", name));
        patched += 1;
    } else if *c_ptr == 0xE9 {
        patched += 1;
    }

    patched == 4
}

fn immortal_watchdog_loop() {
    let gpu_gen = env::var("ENY_GPU_GEN")
        .unwrap_or_else(|_| "unknown".to_string());
    log_msg("Envy Watchdog v4.0.0 (The True Absolute Zero - No Skips, No Limits) started");
    log_msg(&format!("Detected GPU generation: {}", gpu_gen));

    let mut optiscaler_done = false;
    let mut pass1_done = false;
    let mut pass2_done = false;
    let mut pass3_done = false;

    loop {
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
                        log_msg(&format!("=== Neutralizing {} (v4.0 Absolute Zero) ===", mod_str));
                        patch_pass_module(base, &mod_str);
                        *done_ref = true;
                    }

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
