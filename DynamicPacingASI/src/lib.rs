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

fn immortal_watchdog_loop() {
    let gpu_gen = env::var("ENY_GPU_GEN")
        .unwrap_or_else(|_| "unknown".to_string());
    log_msg(&format!("Envy Watchdog v2.0.0 (True Digital Bottomless Pit - Continuous Clamping) started"));
    log_msg(&format!("Detected GPU generation: {}", gpu_gen));
    
    let mut patched_optiscaler = false;
    let mut patched_pass1 = false;
    let mut patched_pass2 = false;
    let mut patched_pass3 = false;
    let mut tick_counter: u64 = 0;

    // TRUE IMMORTAL LOOP: runs for the entire lifetime of the process!
    loop {
        // 1. Monitor and Patch OptiScaler (dxgi.dll / version.dll / etc.)
        if !patched_optiscaler {
            if let Some((base, mod_name)) = get_optiscaler_module() {
                log_msg(&format!("OptiScaler proxy module ({}) found at {:#x}", mod_name, base as usize));
                
                let mut patched_a = false;
                let mut patched_b = false;
                let mut patched_c = false;
                
                unsafe {
                    for i in 0..6_000_000 {
                        let ptr = base.add(i);
                        
                        // PATCH A: NOP the 16ms error counter
                        if !patched_a && *ptr == 0x48 && *ptr.add(1) == 0x83 && *ptr.add(2) == 0xF8 && *ptr.add(3) == 0x10 && *ptr.add(4) == 0x73 && *ptr.add(5) == 0x1B {
                            let error_counter_ptr = ptr.add(0x36) as *mut u8;
                            if *error_counter_ptr == 0x48 && *error_counter_ptr.add(1) == 0x83 && *error_counter_ptr.add(2) == 0x81 {
                                patch_memory(error_counter_ptr, &[0x90, 0x90, 0x90, 0x90, 0x90, 0x90, 0x90, 0x90]);
                                patched_a = true;
                                log_msg(&format!("Patch A (16ms error NOP) applied at offset {:#x}", i + 0x36));
                            }
                        }
                        
                        // PATCH B: Force recovery-pending branch to ALWAYS skip
                        if !patched_b && *ptr == 0x45 && *ptr.add(1) == 0x84 && *ptr.add(2) == 0xC9 &&
                           *ptr.add(3) == 0x0F && *ptr.add(4) == 0x84 && 
                           *ptr.add(5) == 0xD2 && *ptr.add(6) == 0x00 && *ptr.add(7) == 0x00 && *ptr.add(8) == 0x00 {
                            let patch_addr = ptr.add(3) as *mut u8;
                            if *patch_addr == 0x0F {
                                patch_memory(patch_addr, &[0xE9, 0xD3, 0x00, 0x00, 0x00, 0x90]);
                                patched_b = true;
                                log_msg(&format!("Patch B (Recovery Jump) applied at offset {:#x}", i + 3));
                            }
                        }
                        
                        // PATCH C: Force retry-in-1s branch to ALWAYS skip penalty
                        if !patched_c && *ptr == 0xB1 && *ptr.add(1) == 0x01 && *ptr.add(2) == 0x48 && *ptr.add(3) == 0x8B &&
                           *ptr.add(4) == 0x06 && *ptr.add(5) == 0x44 && *ptr.add(12) == 0x84 && *ptr.add(13) == 0xC9 && 
                           *ptr.add(14) == 0x0F && *ptr.add(15) == 0x84 {
                            let patch_addr = ptr.add(14) as *mut u8; 
                            if *patch_addr == 0x0F {
                                patch_memory(patch_addr, &[0xE9, 0xD0, 0x00, 0x00, 0x00, 0x90]);
                                patched_c = true;
                                log_msg(&format!("Patch C (Retry Jump) applied at offset {:#x}", i + 14));
                            }
                        }
                        
                        if patched_a && patched_b && patched_c {
                            patched_optiscaler = true;
                            log_msg("All OptiScaler booby traps neutralized successfully.");
                            break;
                        }
                    }
                }
            }
        }

        // 2. Monitor, Patch, and Continuously Clamp dlssnr_amd_pass1..3.dll
        unsafe {
            let modules = [
                (b"dlssnr_amd_pass1.dll\0", &mut patched_pass1),
                (b"dlssnr_amd_pass2.dll\0", &mut patched_pass2),
                (b"dlssnr_amd_pass3.dll\0", &mut patched_pass3),
            ];

            for (mod_name, is_patched) in modules {
                let handle = GetModuleHandleA(mod_name.as_ptr() as *const i8);
                if !handle.is_null() {
                    let base = handle as *const u8;
                    let mod_str = std::ffi::CStr::from_ptr(mod_name.as_ptr() as *const i8).to_string_lossy();

                    // One-time pattern patch per pass DLL
                    if !*is_patched {
                        log_msg(&format!("{} active in memory at {:#x}, applying bytecode patches...", mod_str, base as usize));
                        
                        let mut found_budget = false;
                        let mut found_recalc_cap = false;

                        for i in 0..4_000_000 {
                            let ptr = base.add(i);
                            
                            // PATTERN 1: Budget Reducer
                            if !found_budget && *ptr == 0x8B && *ptr.add(1) == 0x0D &&
                               *ptr.add(6) == 0x39 && *ptr.add(7) == 0xC8 &&
                               *ptr.add(8) == 0x0F && *ptr.add(9) == 0x4D && *ptr.add(10) == 0xC1 &&
                               *ptr.add(11) == 0x8B && *ptr.add(12) == 0x0D &&
                               *ptr.add(17) == 0x89 && *ptr.add(18) == 0xC2 &&
                               *ptr.add(19) == 0x87 && *ptr.add(20) == 0x15 {
                                let patch_addr = ptr.add(19) as *mut u8;
                                patch_memory(patch_addr, &[0x90, 0x90, 0x90, 0x90, 0x90, 0x90]);
                                log_msg(&format!("Budget reducer NOP'd for {} at offset {:#x}", mod_str, i + 19));
                                found_budget = true;
                            }

                            // PATTERN 3: Dynamic Cap Recalculation
                            if !found_recalc_cap && *ptr == 0xF2 && *ptr.add(1) == 0x48 && *ptr.add(2) == 0x0F && *ptr.add(3) == 0x2C && *ptr.add(4) == 0xC1 &&
                               *ptr.add(5) == 0x87 && *ptr.add(6) == 0x05 &&
                               *ptr.add(11) == 0x8B && *ptr.add(12) == 0x85 && *ptr.add(13) == 0xF8 && *ptr.add(14) == 0x00 {
                                let patch_addr = ptr.add(5) as *mut u8;
                                patch_memory(patch_addr, &[0x90, 0x90, 0x90, 0x90, 0x90, 0x90]);
                                log_msg(&format!("Cap recalculator NOP'd for {} at offset {:#x}", mod_str, i + 5));
                                found_recalc_cap = true;
                            }

                            if found_budget && found_recalc_cap {
                                *is_patched = true;
                                log_msg(&format!("All code patches applied for {}", mod_str));
                                break;
                            }
                        }
                    }

                    // CONTINUOUS LIVE CLAMPING IN RAM:
                    // RVA 0x76C44: Spin iteration cap (normally 1.29M / ~8.7ms) -> set to 2,000,000,000 (~13.3 seconds!)
                    // RVA 0x76C54: Wait budget (normally halves to 50ms) -> set to 2000 ms
                    let cap_ptr = (base as usize + 0x76C44) as *mut u32;
                    let budget_ptr = (base as usize + 0x76C54) as *mut u32;

                    let mut old_protect = 0;
                    if VirtualProtect(cap_ptr as *mut _, 32, PAGE_EXECUTE_READWRITE, &mut old_protect) != 0 {
                        *cap_ptr = 2_000_000_000;
                        *budget_ptr = 2000;
                        VirtualProtect(cap_ptr as *mut _, 32, old_protect, &mut old_protect);
                    }

                    if tick_counter % 30 == 0 && *is_patched {
                        log_msg(&format!("Clamping active for {}: Cap=2B, Budget=2000ms", mod_str));
                    }
                }
            }
        }

        tick_counter += 1;
        thread::sleep(Duration::from_millis(1000));
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
