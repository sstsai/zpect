# Project: Zpect (Zig Reflection & Composition Lab)

## Environment

Zig Version: Master (Nightly)

Manager: zvm

Editor: VS Code Insiders with ZLS

OS: ChromeOS Linux (Crostini)

## Goals & Constraints

Focus: Learning anytype polymorphism and comptime reflection.

Complexity: Prefer clear, documented code over optimized magic.

Standard Library: Use 2026 Zig Master syntax (std.meta.fields).

## Preferred Patterns

Always show a comptime validation check for anytype.

Use std.debug.print for all examples.

Focus on std.io.Writer and std.io.Reader interfaces.

## Build Commands

Run: zig build run

Test: zig test src/main.zig

Update: zvm i --force master && zvm i --zls master