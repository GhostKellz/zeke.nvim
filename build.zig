//! zeke.nvim Build Configuration
//!
//! NOTE: As of the refactor to use Zeke CLI v0.3.0, this plugin
//! no longer requires Zig compilation. This file is kept for
//! compatibility but does nothing.
//!
//! The plugin now works by calling the `zeke` CLI command directly
//! via vim.fn.system() from Lua.

const std = @import("std");

pub fn build(b: *std.Build) void {
    // No-op build
    // Users should install the Zeke CLI separately:
    // https://github.com/ghostkellz/zeke

    const message_step = b.step("info", "Show installation instructions");
    const info_run = b.addSystemCommand(&[_][]const u8{
        "echo",
        "zeke.nvim no longer requires Zig compilation.",
    });
    message_step.dependOn(&info_run.step);

    const info_run2 = b.addSystemCommand(&[_][]const u8{
        "echo",
        "Install Zeke CLI separately: https://github.com/ghostkellz/zeke",
    });
    message_step.dependOn(&info_run2.step);

    // Make info the default step
    b.default_step.dependOn(message_step);
}
