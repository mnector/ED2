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

    // =========================================================================
    // ROOT CAUSE SURGERY (Curing "la herida"):
    //
    // The neural frame drop was controlled by a single master flag at RVA 0x76D54:
    //   0x76D54 >= 0 -> SUCCESS (Render neural frame)
    //   0x76D54 < 0  -> TIMEOUT/DROP (Render raw unscaled game input)
    //
    // 1. RVA 0x1061E initializes 0x76D54 to -1 (0xFFFFFFFF).
    //    We patch the immediate from 0xFFFFFFFF to 0x00000000.
    // 2. RVA 0xF0D1 is a JNE +0x6A that branched straight into the timeout block
    //    if the iteration check failed. We NOP it (75 6A -> 90 90).
    // 3. RVA 0xF293 writes -1 (B8 FF FF FF FF) to 0x76D54 upon timeout.
    //    We patch it to write 0 (B8 00 00 00 00).
    // 4. RVA 0xF138: We KEEP the original JMP (E9 FE 00 00 00) intact!
    //    NOPing it previously caused clean jobs to fall through into the timeout logger!
    // 5. Live RAM Clamping: Every loop iteration, we clamp 0x76D54 directly to 0,
    //    guaranteeing that 0xDF88 (JS), 0xA128 (JNS), and 0xB5BC (JNS) ALWAYS see 0 (Success).
    // =========================================================================

    // 1. Patch initial keep_input_flag at RVA 0x1061E: C7 05 2C 67 06 00 [FF FF FF FF] -> [00 00 00 00]
    let init_flag_ptr = (base as usize + 0x1061E) as *mut u8;
    if *init_flag_ptr == 0xC7 && *init_flag_ptr.add(1) == 0x05 {
        let imm_ptr = (base as usize + 0x1061E + 6) as *mut u32;
        let mut old_p = 0;
        if VirtualProtect(imm_ptr as *mut _, 4, PAGE_EXECUTE_READWRITE, &mut old_p) != 0 {
            *imm_ptr = 0;
            VirtualProtect(imm_ptr as *mut _, 4, old_p, &mut old_p);
            log_msg(&format!("[{}] Root fix #1: Init keep_input_flag patched to 0 (Success) at RVA 0x1061E", name));
            count += 1;
        }
    } else { count += 1; }

    // 2. Patch JNE +0x6A branch into timeout block at RVA 0xF0D1: 75 6A -> 90 90
    let timeout_branch = (base as usize + 0xF0D1) as *mut u8;
    if *timeout_branch == 0x75 && *timeout_branch.add(1) == 0x6A {
        patch_memory(timeout_branch, &[0x90, 0x90]);
        log_msg(&format!("[{}] Root fix #2: Timeout JNE branch NOP'd at RVA 0xF0D1", name));
        count += 1;
    } else if *timeout_branch == 0x90 { count += 1; }

    // 3. Patch timeout keep_input write at RVA 0xF293: B8 FF FF FF FF -> B8 00 00 00 00
    let timeout_write = (base as usize + 0xF293) as *mut u8;
    if *timeout_write == 0xB8 {
        let imm_ptr = (base as usize + 0xF293 + 1) as *mut u32;
        let mut old_p = 0;
        if VirtualProtect(imm_ptr as *mut _, 4, PAGE_EXECUTE_READWRITE, &mut old_p) != 0 {
            *imm_ptr = 0;
            VirtualProtect(imm_ptr as *mut _, 4, old_p, &mut old_p);
            log_msg(&format!("[{}] Root fix #3: Timeout write forced to 0 at RVA 0xF293", name));
            count += 1;
        }
    }

    // 4. Auxiliary: NOP the host watchdog and iteration cap conditional jumps
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

    // 5. Auxiliary: NOP budget and cap degraders
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

    // 6. Direct Live RAM Clamping
    let ram_cap_ptr = (base as usize + 0x76C44) as *mut u32;
    let ram_budget_ptr = (base as usize + 0x76C54) as *mut u32;
    let ram_keep_ptr = (base as usize + 0x76D54) as *mut i32;
    let mut old_protect = 0;
    if VirtualProtect(ram_cap_ptr as *mut _, 300, PAGE_EXECUTE_READWRITE, &mut old_protect) != 0 {
        *ram_cap_ptr = 2_000_000_000;
        *ram_budget_ptr = 2000;
        *ram_keep_ptr = 0; // ALWAYS SUCCESS
        VirtualProtect(ram_cap_ptr as *mut _, 300, old_protect, &mut old_protect);
    }

    log_msg(&format!("[{}] True Cure Applied: All {} patches active, master flag locked to 0.", name, count));
}

unsafe fn patch_optiscaler(base: *const u8, name: &str) -> bool {
    let mut patched = 0;

    // OptiScaler AMD skipped 16ms bypass
    // At 0x14585: 73 6A (JAE +0x6A) -> Change to EB 6A (JMP +0x6A)
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
    log_msg("Envy Watchdog v5.0.0 (True Wound Cured - Zero Drops, Zero Fakes) started");
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
                        log_msg(&format!("=== Curing {} ===", mod_str));
                        patch_pass_module(base, &mod_str);
                        *done_ref = true;
                    }

                    // Continuous Live RAM Clamping
                    let ram_cap = (base as usize + 0x76C44) as *mut u32;
                    let ram_budget = (base as usize + 0x76C54) as *mut u32;
                    let ram_keep = (base as usize + 0x76D54) as *mut i32;
                    let mut old_p = 0;
                    if VirtualProtect(ram_cap as *mut _, 300, PAGE_EXECUTE_READWRITE, &mut old_p) != 0 {
                        *ram_cap = 2_000_000_000;
                        *ram_budget = 2000;
                        *ram_keep = 0; // Lock to SUCCESS every tick
                        VirtualProtect(ram_cap as *mut _, 300, old_p, &mut old_p);
                    }
                }
            }
        }

        thread::sleep(Duration::from_millis(50)); // Fast 50ms tick for live clamping
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
