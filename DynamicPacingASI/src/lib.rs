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
    unsafe {
        let dxgi_handle = GetModuleHandleA(b"dxgi.dll\0".as_ptr() as *const i8);
        if !dxgi_handle.is_null() {
            let base = dxgi_handle as *const u8;
            
            for i in 0..4_000_000 {
                let ptr = base.add(i);
                
                // PATCH A (v8.0): NOP the 16ms skip error counter
                if *ptr == 0x48 && *ptr.add(1) == 0x83 && *ptr.add(2) == 0xF8 && *ptr.add(3) == 0x10 && *ptr.add(4) == 0x73 && *ptr.add(5) == 0x1B {
                    let error_counter_ptr = ptr.add(0x36) as *mut u8;
                    if *error_counter_ptr == 0x48 && *error_counter_ptr.add(1) == 0x83 && *error_counter_ptr.add(2) == 0x81 {
                        patch_memory(error_counter_ptr, &[0x90, 0x90, 0x90, 0x90, 0x90, 0x90, 0x90, 0x90]);
                    }
                }
                
                // PATCH B (v14.0): Force the recovery-pending branch to ALWAYS skip
                // Pattern: 45 84 C9  0F 84 D2 00 00 00
                //          test r9b,r9b  je near +0xD2
                // Replace the je (0F 84) with jmp (E9) to ALWAYS skip recovery
                // je near = 0F 84 D2 00 00 00  (6 bytes)
                // jmp near = E9 D3 00 00 00 90 (5 bytes + 1 NOP)
                // offset is D2+1=D3 because jmp near is 5 bytes vs je near's 6
                if *ptr == 0x45 && *ptr.add(1) == 0x84 && *ptr.add(2) == 0xC9 &&
                   *ptr.add(3) == 0x0F && *ptr.add(4) == 0x84 && 
                   *ptr.add(5) == 0xD2 && *ptr.add(6) == 0x00 && *ptr.add(7) == 0x00 && *ptr.add(8) == 0x00 {
                    // Change je near -> jmp near (unconditional)
                    // je near (0F 84 rel32) is 6 bytes, jmp near (E9 rel32) is 5 bytes
                    // New offset = old_offset + 1 (because jmp is 1 byte shorter)
                    let patch_addr = ptr.add(3) as *mut u8;
                    if *patch_addr == 0x0F { // Only patch once
                        patch_memory(patch_addr, &[0xE9, 0xD3, 0x00, 0x00, 0x00, 0x90]);
                    }
                }
            }
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
