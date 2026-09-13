use std::fs::{File, OpenOptions};
use std::io::{Read, Seek, SeekFrom, Write};
use std::path::{Path, PathBuf};
use std::thread;
use std::time::{Duration, Instant};
use winapi::shared::minwindef::{BOOL, DWORD, HINSTANCE, LPVOID, TRUE};
use winapi::um::winnt::DLL_PROCESS_ATTACH;

const MIN_FPS: f64 = 45.0;
const MAX_FPS: f64 = 120.0;
const STEP_DOWN: f64 = 0.08;
const STEP_UP: f64 = 0.02;
const UP_DELAY_MS: u64 = 8000;

fn get_game_dir() -> Option<PathBuf> {
    if let Ok(path) = std::env::current_exe() {
        return path.parent().map(|p| p.to_path_buf());
    }
    None
}

fn read_current_limit(ini_path: &Path) -> f64 {
    if let Ok(content) = std::fs::read_to_string(ini_path) {
        for line in content.lines() {
            if line.starts_with("FramerateLimit=") {
                if let Some(val_str) = line.split('=').nth(1) {
                    if let Ok(val) = val_str.trim().parse::<f64>() {
                        if val > 0.0 { return val; }
                    }
                }
            }
        }
    }
    MAX_FPS
}

fn set_current_limit(ini_path: &Path, mut new_limit: f64) {
    if new_limit < MIN_FPS { new_limit = MIN_FPS; }
    if new_limit > MAX_FPS { new_limit = MAX_FPS; }
    let new_limit = new_limit.round();

    if let Ok(content) = std::fs::read_to_string(ini_path) {
        let mut new_content = String::with_capacity(content.len());
        let mut replaced = false;
        
        for line in content.lines() {
            if line.starts_with("FramerateLimit=") {
                new_content.push_str(&format!("FramerateLimit={}\r\n", new_limit));
                replaced = true;
            } else {
                new_content.push_str(line);
                new_content.push_str("\r\n");
            }
        }
        
        if !replaced {
            new_content.push_str(&format!("\r\n[Framerate]\r\nFramerateLimit={}\r\n", new_limit));
        }
        let _ = std::fs::write(ini_path, new_content);
    }
}

fn pacing_loop() {
    let game_dir = match get_game_dir() { Some(dir) => dir, None => return };
    let ini_path = game_dir.join("OptiScaler.ini");
    let log_path = game_dir.join("dlssnr_on_amd.log");
    
    let mut current_limit = read_current_limit(&ini_path);
    if current_limit < MIN_FPS || current_limit == 0.0 {
        set_current_limit(&ini_path, MAX_FPS);
    }
    
    let mut file: Option<File> = None;
    let mut pos: u64 = 0;
    let mut last_spike = Instant::now();

    loop {
        thread::sleep(Duration::from_millis(250));
        
        if file.is_none() {
            if let Ok(mut f) = File::open(&log_path) {
                let _ = f.seek(SeekFrom::End(0));
                pos = f.stream_position().unwrap_or(0);
                file = Some(f);
            }
        }
        
        let mut spike = false;
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
                        if line.contains("timeout") || line.contains("SPIKE") || line.contains("skipped") {
                            spike = true;
                        }
                    }
                }
            }
        }
        
        if spike {
            last_spike = Instant::now();
            let current = read_current_limit(&ini_path);
            let mut new_limit = (current * (1.0 - STEP_DOWN)).floor();
            if current - new_limit < 1.0 { new_limit = current - 1.0; }
            set_current_limit(&ini_path, new_limit);
        } else {
            if last_spike.elapsed().as_millis() as u64 >= UP_DELAY_MS {
                let current = read_current_limit(&ini_path);
                if current < MAX_FPS {
                    let mut new_limit = (current * (1.0 + STEP_UP)).ceil();
                    if new_limit - current < 1.0 { new_limit = current + 1.0; }
                    set_current_limit(&ini_path, new_limit);
                }
                last_spike = Instant::now();
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
