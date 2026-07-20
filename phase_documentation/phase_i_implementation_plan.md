# Phase I Implementation Plan Document

## Core Architecture Modifications
1. **Live Grid Interaction**:
   - `LiveGridPage._buildGridSlot`: `onTap` checks whether slot has an assigned camera.
   - If assigned and grid size is 2 or 3 (4-grid or 9-grid), `setState` updates `_layoutGridSize = 1` and selects the slot.

2. **PTZ Control Scoping**:
   - `VideoTile`: Renders PTZ overlay only when `widget.camera.ptzCapable && widget.showPtzOverlay`.
   - `LiveGridPage`: Passes `showPtzOverlay: _layoutGridSize == 1 && _isPTZActive`.
   - Toolbar PTZ toggle switches `_layoutGridSize` to 1 if user activates PTZ from grid view.

3. **Data Layer Stream Enrichment**:
   - `CameraRepository`: Returns distinct video stream URLs for `cam-001` through `cam-009`.
