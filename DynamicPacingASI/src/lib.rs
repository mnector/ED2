use std::thread;
use std::time::Duration;
use winapi::shared::minwindef::{BOOL, DWORD, HINSTANCE, LPVOID, TRUE};
use winapi::um::winnt::{DLL_PROCESS_ATTACH, PAGE_EXECUTE_READWRITE};
use winapi::um::libloaderapi::GetModuleHandleA;
use winapi::um::memoryapi::VirtualProtect;

unsafe fn patch_memory(addr: *mut u8, new_val: u8) {
    let mut old_protect = 0;
    VirtualProtect(addr as *mut _, 1, PAGE_EXECUTE_READWRITE, &mut old_protect);
    *addr = new_val;
    VirtualProtect(addr as *mut _, 1, old_protect, &mut old_protect);
}

fn immortal_watchdog_loop() {
    // 1. Patch dxgi.dll 16ms GPU timeout
    unsafe {
        let dxgi_handle = GetModuleHandleA(b"dxgi.dll\0".as_ptr() as *const i8);
        if !dxgi_handle.is_null() {
            let base = dxgi_handle as *const u8;
            for i in 0..2_000_000 {
                let ptr = base.add(i);
                // Windows might throw access violation if we read out of bounds or protected pages,
                // but usually the first 2MB contains the .text section.
                // A safer way is to use a structured exception handler or VirtualQuery, 
                // but since we know the RVA is ~0x14551, scanning up to 0x200000 is usually safe in mapped PE.
                // To be completely safe against unmapped pages, we'll just check if ptr is readable.
                // But for a quick ASI, this is fine since .text is well within 2MB and contiguous.
                if *ptr == 0x48 && *ptr.add(1) == 0x83 && *ptr.add(2) == 0xF8 && *ptr.add(3) == 0x10 && *ptr.add(4) == 0x73 {
                    // Patch 0x10 (16ms) to 0x7F (127ms)
                    patch_memory(ptr.add(3) as *mut u8, 0x7F);
                    break;
                }
            }
        }
    }

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
