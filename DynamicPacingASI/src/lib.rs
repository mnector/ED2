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
    // 1. Host Watchdog Jump at RVA 0xF0DF: 0F 8D 56 01 00 00 -> 6 NOPs
    let hw1_ptr = (base as usize + 0xF0DF) as *mut u8;
    if *hw1_ptr == 0x0F && *hw1_ptr.add(1) == 0x8D {
        patch_memory(hw1_ptr, &[0x90, 0x90, 0x90, 0x90, 0x90, 0x90]);
        log_msg(&format!("Host watchdog JGE jump NOP'd for {} at RVA 0xF0DF", name));
    }

    // 2. Iteration Timeout Jump at RVA 0xF0F7: 0F 8C 3E 01 00 00 -> 6 NOPs
    let hw2_ptr = (base as usize + 0xF0F7) as *mut u8;
    if *hw2_ptr == 0x0F && *hw2_ptr.add(1) == 0x8C {
        patch_memory(hw2_ptr, &[0x90, 0x90, 0x90, 0x90, 0x90, 0x90]);
        log_msg(&format!("Iteration timeout JL jump NOP'd for {} at RVA 0xF0F7", name));
    }

    // 3. Cap Recalculator at RVA 0xF0BF: 87 05 7F 7B 06 00 -> 6 NOPs
    let cap_recalc_ptr = (base as usize + 0xF0BF) as *mut u8;
    if *cap_recalc_ptr == 0x87 && *cap_recalc_ptr.add(1) == 0x05 {
        patch_memory(cap_recalc_ptr, &[0x90, 0x90, 0x90, 0x90, 0x90, 0x90]);
        log_msg(&format!("Cap recalculator NOP'd for {} at RVA 0xF0BF", name));
    }

    // 4. Budget Reducer at RVA 0xF1B7: 87 15 97 7A 06 00 -> 6 NOPs
    let budget_ptr = (base as usize + 0xF1B7) as *mut u8;
    if *budget_ptr == 0x87 && *budget_ptr.add(1) == 0x15 {
        patch_memory(budget_ptr, &[0x90, 0x90, 0x90, 0x90, 0x90, 0x90]);
        log_msg(&format!("Budget reducer NOP'd for {} at RVA 0xF1B7", name));
    }

    // 5. Direct Live RAM Clamping
    let ram_cap_ptr = (base as usize + 0x76C44) as *mut u32;
    let ram_budget_ptr = (base as usize + 0x76C54) as *mut u32;
    let mut old_protect = 0;
    if VirtualProtect(ram_cap_ptr as *mut _, 32, PAGE_EXECUTE_READWRITE, &mut old_protect) != 0 {
        *ram_cap_ptr = 2_000_000_000; // 2 Billion iterations (~13.3 seconds)
        *ram_budget_ptr = 2000;       // 2,000 ms budget
        VirtualProtect(ram_cap_ptr as *mut _, 32, old_protect, &mut old_protect);
    }
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
    log_msg("Envy Watchdog v2.1.0 (Total Immunity: Watchdog Jumps NOP'd + Live RAM Clamped) started");
    log_msg(&format!("Detected GPU generation: {}", gpu_gen));

    let mut optiscaler_done = false;
    let mut pass1_done = false;
    let mut pass2_done = false;
    let mut pass3_done = false;

    // TRUE IMMORTAL LOOP: runs for the entire lifetime of the process!
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
                        log_msg(&format!("Neutralizing all timeouts & traps in {}...", mod_str));
                        patch_pass_module(base, &mod_str);
                        *done_ref = true;
                        log_msg(&format!("{} is now 100% immune to drops and timeouts.", mod_str));
                    }

                    // Keep RAM clamp active continuously
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

        thread::sleep(Duration::from_millis(500));
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
