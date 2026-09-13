use std::thread;
use std::time::Duration;
use winapi::shared::minwindef::{BOOL, DWORD, HINSTANCE, LPVOID, TRUE};
use winapi::um::winnt::DLL_PROCESS_ATTACH;
use winapi::um::libloaderapi::GetModuleHandleA;

fn immortal_watchdog_loop() {
    loop {
        thread::sleep(Duration::from_millis(100));
        
        unsafe {
            let modules = [
                b"dlssnr_amd_pass1.dll\0",
                b"dlssnr_amd_pass2.dll\0",
                b"dlssnr_amd_pass3.dll\0",
            ];
            
            for &mod_name in &modules {
                let handle = GetModuleHandleA(mod_name.as_ptr() as *const i8);
                if !handle.is_null() {
                    let base = handle as u64;
                    let cap_ptr = (base + 0x76c44) as *mut u32;
                    let current_cap = std::ptr::read_volatile(cap_ptr);
                    
                    // 0x3B9AC9FF = 999999999
                    if current_cap < 999999999 {
                        std::ptr::write_volatile(cap_ptr, 999999999);
                    }
                }
            }
        }
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
