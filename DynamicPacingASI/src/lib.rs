use std::thread;
use std::time::Duration;
use winapi::shared::minwindef::{BOOL, DWORD, HINSTANCE, LPVOID, TRUE};
use winapi::um::winnt::{DLL_PROCESS_ATTACH, PAGE_EXECUTE_READWRITE};
use winapi::um::libloaderapi::GetModuleHandleA;
use winapi::um::memoryapi::VirtualProtect;

unsafe fn patch_memory(addr: *mut u8, bytes: &[u8]) {
    let mut old_protect = 0;
    VirtualProtect(addr as *mut _, bytes.len(), PAGE_EXECUTE_READWRITE, &mut old_protect);
    std::ptr::copy_nonoverlapping(bytes.as_ptr(), addr, bytes.len());
    VirtualProtect(addr as *mut _, bytes.len(), old_protect, &mut old_protect);
}

fn immortal_watchdog_loop() {
    // v8.0 ONLY: Patch dxgi.dll to NOP the 16ms skip error counter
    // This is the only patch proven to be safe and stable.
    // The trampoline patches (v11/v12) are REMOVED because they corrupt
    // the neural network state by jumping to the success block with
    // unpopulated GPU buffers, causing "img:invalid argument" errors.
    unsafe {
        let dxgi_handle = GetModuleHandleA(b"dxgi.dll\0".as_ptr() as *const i8);
        if !dxgi_handle.is_null() {
            let base = dxgi_handle as *const u8;
            for i in 0..2_000_000 {
                let ptr = base.add(i);
                if *ptr == 0x48 && *ptr.add(1) == 0x83 && *ptr.add(2) == 0xF8 && *ptr.add(3) == 0x10 && *ptr.add(4) == 0x73 && *ptr.add(5) == 0x1B {
                    let error_counter_ptr = ptr.add(0x36) as *mut u8;
                    if *error_counter_ptr == 0x48 && *error_counter_ptr.add(1) == 0x83 && *error_counter_ptr.add(2) == 0x81 {
                        patch_memory(error_counter_ptr, &[0x90, 0x90, 0x90, 0x90, 0x90, 0x90, 0x90, 0x90]);
                    }
                    break;
                }
            }
        }
    }
    
    // Keep thread alive for future use
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
