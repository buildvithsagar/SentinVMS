# Phase E: Premium Dark Glassmorphism Context & 3x3 Grid Layout

## Overview
The user requested:
1. Re-designing the main Dashboard (Live Grid View) and all other pages to match the premium dark tactical industrial style of the login page (Completed).
2. Supporting a **3x3 grid layout (9 concurrent live camera streams)** on the main Dashboard so that larger camera sites can be monitored simultaneously.
3. Overriding the 4-decoder pool capacity limit to scale up to **9 concurrent streams** at high quality (Main Stream), prioritizing optimal resolution and quality for users on modern 4GB+ RAM devices.

## Design Decisions
1. **Decoder Pool capacity:** Upgraded `maxDecoders` from 4 to 9 in production dependency injection, preserving high-quality feeds across all layouts.
2. **Dashboard layout modes:** Expanded support in `LiveGridPage` to support 1x1 Focus, 2x2 Grid, and 3x3 Grid layout modes, with layout controls and state variables.
3. **Empty slots & borders:** Styled 9 empty slots as glassmorphic elements (`Colors.white.withValues(alpha: 0.03)`) with a white dashed border (`Colors.white12`).
