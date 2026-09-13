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
    // 1. Patch dxgi.dll to NOP the 16ms skip error counter (from v8.0)
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

    // 2. Continuous loop to patch all 3 AMD passes
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
                    
                    // A. The Iteration Cap (v6.0)
                    let cap_ptr = (base + 0x76c44) as *mut u32;
                    let current_cap = std::ptr::read_volatile(cap_ptr);
                    if current_cap < 999999999 {
                        std::ptr::write_volatile(cap_ptr, 999999999);
                    }
                    
                    // B. The Budget Abort Patch (v9.0)
                    // We scan for: B8 FF FF FF FF 87 05 ?? ?? ?? ?? E9
                    // Which is: mov eax, -1 ; xchg eax, [rel...] ; jmp ...
                    // We replace B8 FF FF FF FF with 31 C0 90 90 90 (xor eax, eax ; nop nop nop)
                    // This forces the worker to ALWAYS report SUCCESS (0) instead of TIMEOUT/ABORT (-1),
                    // preventing the 1-second OptiScaler punishment when the game naturally stutters!
                    for i in 0x1000..0x200000 {
                        let ptr = (base + i) as *mut u8;
                        if *ptr == 0xB8 && *ptr.add(1) == 0xFF && *ptr.add(2) == 0xFF && *ptr.add(3) == 0xFF && *ptr.add(4) == 0xFF {
                            if *ptr.add(5) == 0x87 && *ptr.add(6) == 0x05 && *ptr.add(11) == 0xE9 {
                                patch_memory(ptr, &[0x31, 0xC0, 0x90, 0x90, 0x90]);
                                break;
                            }
                        }
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
