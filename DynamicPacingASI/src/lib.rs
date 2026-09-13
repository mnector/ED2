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
                    
                    // B. The Budget Abort Patch (v10.0)
                    // We scan for: B8 FF FF FF FF 87 05 ?? ?? ?? ?? E9
                    // Which is: mov eax, -1 ; xchg eax, [rel...] ; jmp ...
                    // In v9.0 we only patched the 'mov eax, -1' to 'xor eax, eax'.
                    // However, 'xchg' swapped our '0' with the OLD value of the memory location,
                    // which is pre-initialized to -1 by dlssnr! So 'eax' STILL became -1, and OptiScaler STILL triggered the 1s timeout penalty!
                    // In v10.0, we patch the ENTIRE 11 bytes to:
                    // xor eax, eax
                    // mov [rel...], eax
                    // nop nop nop
                    // This explicitly sets BOTH eax and the memory location to 0, ensuring an absolute Success return.
                    for i in 0x1000..0x200000 {
                        let ptr = (base + i) as *mut u8;
                        if *ptr == 0xB8 && *ptr.add(1) == 0xFF && *ptr.add(2) == 0xFF && *ptr.add(3) == 0xFF && *ptr.add(4) == 0xFF {
                            if *ptr.add(5) == 0x87 && *ptr.add(6) == 0x05 && *ptr.add(11) == 0xE9 {
                                // Calculate the new RIP offset for mov [rel], eax
                                let old_offset = std::ptr::read_unaligned(ptr.add(7) as *const i32);
                                let target_addr = (ptr as i64) + 5 + 6 + (old_offset as i64);
                                let new_mov_addr = (ptr as i64) + 2;
                                let new_offset = (target_addr - (new_mov_addr + 6)) as i32;

                                let mut patch = [0u8; 11];
                                patch[0] = 0x31; patch[1] = 0xC0; // xor eax, eax
                                patch[2] = 0x89; patch[3] = 0x05; // mov [rel...], eax
                                patch[4..8].copy_from_slice(&new_offset.to_le_bytes());
                                patch[8] = 0x90; patch[9] = 0x90; patch[10] = 0x90; // nop nop nop

                                patch_memory(ptr, &patch);
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
