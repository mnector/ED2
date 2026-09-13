use std::fs::{File, OpenOptions};
use std::io::{Read, Seek, SeekFrom, Write};
use std::path::{Path, PathBuf};
use std::thread;
use std::time::{Duration, Instant};
use winapi::shared::minwindef::{BOOL, DWORD, HINSTANCE, LPVOID, TRUE};
use winapi::um::winnt::DLL_PROCESS_ATTACH;

fn get_game_dir() -> Option<PathBuf> {
    if let Ok(path) = std::env::current_exe() {
        return path.parent().map(|p| p.to_path_buf());
    }
    None
}

fn set_ini_value(ini_path: &Path, section: &str, key: &str, value: &str) {
    if let Ok(content) = std::fs::read_to_string(ini_path) {
        let mut new_content = String::with_capacity(content.len());
        let mut in_section = false;
        let mut replaced = false;
        
        for line in content.lines() {
            if line.starts_with('[') {
                in_section = line.trim() == format!("[{}]", section);
            }
            
            if in_section && line.starts_with(&format!("{}=", key)) {
                new_content.push_str(&format!("{}={}\r\n", key, value));
                replaced = true;
            } else {
                new_content.push_str(line);
                new_content.push_str("\r\n");
            }
        }
        
        if replaced {
            let _ = std::fs::write(ini_path, new_content);
        }
    }
}

fn pacing_loop() {
    let game_dir = match get_game_dir() {
        Some(dir) => dir,
        None => return,
    };
    
    let ini_path = game_dir.join("OptiScaler.ini");
    let log_path = game_dir.join("dlssnr_on_amd.log");
    
    let mut file: Option<File> = None;
    let mut pos: u64 = 0;
    
    let mut healing_mode = false;
    let mut healing_start = Instant::now();

    loop {
        thread::sleep(Duration::from_millis(50));
        
        if healing_mode && healing_start.elapsed().as_millis() > 4000 {
            healing_mode = false;
            // Restore full quality after 4 seconds of healing (easily > 100 frames to reset budget)
            set_ini_value(&ini_path, "DlssNr", "AmdModelScale", "1");
        }
        
        if file.is_none() {
            if let Ok(mut f) = File::open(&log_path) {
                let _ = f.seek(SeekFrom::End(0));
                pos = f.stream_position().unwrap_or(0);
                file = Some(f);
            }
        }
        
        if let Some(f) = file.as_mut() {
            let current_len = f.metadata().map(|m| m.len()).unwrap_or(pos);
            if current_len < pos {
                pos = 0;
                let _ = f.seek(SeekFrom::Start(0));
            }
            
            let _ = f.seek(SeekFrom::Start(pos));
            let mut buffer = String::new();
            if let Ok(bytes_read) = f.read_to_string(&mut buffer) {
                if bytes_read > 0 {
                    pos += bytes_read as u64;
                    for line in buffer.lines() {
                        // Detect the death spiral trigger!
                        if line.contains("host watchdog fired") || line.contains("timeout") || line.contains("SPIKE") {
                            if !healing_mode {
                                healing_mode = true;
                                healing_start = Instant::now();
                                // Hack the proxy: force compute to 0.1x so it finishes in 1ms.
                                // This allows the proxy to hit 100 clean frames instantly and restore its 192ms budget cap!
                                set_ini_value(&ini_path, "DlssNr", "AmdModelScale", "0.1");
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
    if call_reason == DLL_PROCESS_ATTACH { thread::spawn(move || { pacing_loop(); }); }
    TRUE
}
#[no_mangle]
#[allow(non_snake_case)]
pub extern "C" fn InitializeASI() {}
