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
                    
                    // C. The Ultimate Success Trampoline (v11.0)
                    // We intercept the universal abort handler and redirect it to the success handler, 
                    // while perfectly restoring the required registers.
                    let mut abort_ptr: *mut u8 = std::ptr::null_mut();
                    let mut success_ptr: *mut u8 = std::ptr::null_mut();
                    
                    for i in 0x1000..0x200000 {
                        let ptr = (base + i) as *mut u8;
                        if abort_ptr.is_null() && 
                           *ptr == 0x4C && *ptr.add(1) == 0x89 && *ptr.add(2) == 0xF2 && 
                           *ptr.add(3) == 0x49 && *ptr.add(4) == 0x89 && *ptr.add(5) == 0xF8 && 
                           *ptr.add(6) == 0x41 && *ptr.add(7) == 0xB9 && *ptr.add(8) == 0x02 && 
                           *ptr.add(9) == 0x00 && *ptr.add(10) == 0x00 && *ptr.add(11) == 0x00 {
                            abort_ptr = ptr.sub(7);
                        }
                        if success_ptr.is_null() && 
                           *ptr == 0x85 && *ptr.add(1) == 0xC0 && *ptr.add(2) == 0x4C && 
                           *ptr.add(3) == 0x8B && *ptr.add(4) == 0xB5 && *ptr.add(5) == 0xC8 && 
                           *ptr.add(6) == 0x00 && *ptr.add(7) == 0x00 && *ptr.add(8) == 0x00 {
                            success_ptr = ptr;
                        }
                        if !abort_ptr.is_null() && !success_ptr.is_null() {
                            break;
                        }
                    }

                    if !abort_ptr.is_null() && !success_ptr.is_null() {
                        if *abort_ptr.add(7) != 0x31 || *abort_ptr.add(8) != 0xC0 {
                            let orig_rel = std::ptr::read_unaligned(abort_ptr.add(3) as *const i32);
                            let new_rel = orig_rel + 8;
                            
                            let jmp_offset = (success_ptr as i64 - (abort_ptr as i64 + 14)) as i32;

                            let mut patch = [0u8; 14];
                            patch[0] = 0x48; patch[1] = 0x8B; patch[2] = 0x0D; // mov rcx, [rel]
                            patch[3..7].copy_from_slice(&new_rel.to_le_bytes());
                            patch[7] = 0x31; patch[8] = 0xC0; // xor eax, eax
                            patch[9] = 0xE9; // jmp near
                            patch[10..14].copy_from_slice(&jmp_offset.to_le_bytes());

                            patch_memory(abort_ptr, &patch);
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
