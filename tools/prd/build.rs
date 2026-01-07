fn main() {
    // Link AppKit framework on macOS for notify-rust/mac-notification-sys
    #[cfg(target_os = "macos")]
    {
        println!("cargo:rustc-link-lib=framework=AppKit");
    }
}
