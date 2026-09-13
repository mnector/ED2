use std::thread;
use std::time::Duration;
use std::fs::OpenOptions;
use std::io::Write;
use winapi::shared::minwindef::{BOOL, DWORD, HINSTANCE, LPVOID, TRUE};
use winapi::um::winnt::{DLL_PROCESS_ATTACH, PAGE_EXECUTE_READWRITE};
use winapi::um::memoryapi::VirtualProtect;
use winapi::um::psapi::{EnumProcessModules, GetModuleFileNameExA};
use winapi::um::processthreadsapi::GetCurrentProcess;

unsafe fn patch_memory(addr: *mut u8, bytes: &[u8]) {
    let mut old_protect = 0;
    VirtualProtect(addr as *mut _, bytes.len(), PAGE_EXECUTE_READWRITE, &mut old_protect);
    std::ptr::copy_nonoverlapping(bytes.as_ptr(), addr, bytes.len());
    VirtualProtect(addr as *mut _, bytes.len(), old_protect, &mut old_protect);
}

fn log_msg(msg: &str) {
    if let Ok(mut file) = OpenOptions::new().create(true).append(true).open("F:\\Steam\\steamapps\\common\\Palworld\\Pal\\Binaries\\Win64\\envy_asi.log") {
        let _ = writeln!(file, "{}", msg);
    }
}

fn get_optiscaler_module() -> Option<*const u8> {
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
                    if name.contains("dxgi.dll") && !name.contains("system32") {
                        return Some(modules[i] as *const u8);
                    }
                }
            }
        }
    }
    None
}

fn immortal_watchdog_loop() {
    log_msg("Envy Watchdog v14.2 started");
    unsafe {
        if let Some(base) = get_optiscaler_module() {
            log_msg(&format!("OptiScaler dxgi.dll found at {:#x}", base as usize));
            
            let mut patched_a = false;
            let mut patched_b = false;
            
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
                    log_msg(&format!("Found Pattern B at offset {:#x}", i));
                    if *patch_addr == 0x0F {
                        patch_memory(patch_addr, &[0xE9, 0xD3, 0x00, 0x00, 0x00, 0x90]);
                        patched_b = true;
                        log_msg(&format!("Patch B (Recovery Jump) applied at offset {:#x}", i + 3));
                    }
                }
                
                if patched_a && patched_b {
                    break;
                }
            }
            if !patched_a { log_msg("Patch A NOT applied!"); }
            if !patched_b { log_msg("Patch B NOT applied!"); }
        } else {
            log_msg("OptiScaler dxgi.dll not found in process modules!");
        }
    }
    
    // Keep thread alive
    loop {
        thread::sleep(Duration::from_secs(60));
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
