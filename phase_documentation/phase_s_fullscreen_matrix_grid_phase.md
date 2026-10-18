# Phase S: Fullscreen Responsive Matrix Grid & Viewport Auto-Fitting

## 1. Specification Overview
* **Scope:** Dynamic matrix layout calculation, hardware cutout avoidance, and smooth orientation handling in `LiveGridPage`.
* **Design Guidelines:** Dark Slate `#0F172A`, Electric Teal `#2DD4BF`, and translucent glass overlay widgets.

## 2. Key Changes
* Created `_buildMatrixGrid(int gridSize)` with responsive `LayoutBuilder`.
* Wrapped fullscreen body inside `SafeArea`.
* Cleaned up orientation handling in `_toggleFullScreen()`.
