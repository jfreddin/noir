import QtQuick

// The controller's focus ring. It sits over the control the left stick has
// selected, snaps to the next one in the pressed direction and takes the
// control's size. A list or grid is one control: the stick moves through its
// rows, scrolling them, and the ring sits on the current row. Inside the sidebar
// or the pinned drawer it prefers that region's controls, and it leaves only
// when nothing there lies that way. `scope` limits the search: an open dialog
// or menu keeps the focus inside itself.
Item {
    id: ring
    property Item scope: window.contentItem
    // Regions that prefer their own controls: the sidebar and the pinned drawer.
    property Item rail: null
    property Item drawer: null
    property Item target: null
    // The list or grid the target row belongs to, or null.
    property Item view: null
    // The control the ring was on when the stick moved it into a list; O returns there.
    property Item origin: null
    // Where the ring goes back to when a menu it opened closes.
    property Item returnView: null
    property int returnIndex: -1
    property bool shown: gamepad.active && target !== null
    // Where the ring is drawn, in window coordinates.
    property var geo: ({ x: 0, y: 0, width: 0, height: 0 })

    z: 1000
    visible: shown
    x: geo.x - 4; y: geo.y - 4
    width: geo.width + 8; height: geo.height + 8
    // Spring for position and size, so it snaps and settles rather than jumping.
    Behavior on x { enabled: app.motion; NumberAnimation { duration: Theme.springSpatialMs; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.springSpatial } }
    Behavior on y { enabled: app.motion; NumberAnimation { duration: Theme.springSpatialMs; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.springSpatial } }
    Behavior on width { enabled: app.motion; NumberAnimation { duration: Theme.springSpatialMs; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.springSpatial } }
    Behavior on height { enabled: app.motion; NumberAnimation { duration: Theme.springSpatialMs; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.springSpatial } }

    // Mid-grey when focused; white when the control is the active one.
    readonly property color ink: ring.target && (ring.target.checked || ring.target.selected) ? Theme.text : Theme.outline
    Rectangle {
        anchors.fill: parent
        color: "transparent"
        border.width: 2
        border.color: ring.ink
    }

    // Pixel grain: 2px squares strung along the border that flicker on a slow
    // tick. Each square is placed by its share of the perimeter, so the grain
    // follows the ring as it resizes.
    readonly property int grainCount: 64
    // 1 at the moment the ring snaps to a new control, easing to 0 on the effects spring.
    property real flash: 0
    NumberAnimation {
        id: flashAnim
        target: ring; property: "flash"; from: 1; to: 0
        duration: Theme.springEffectsMs; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.springEffects
    }
    onTargetChanged: if (target) { flashAnim.restart() }
    function edgePoint(index) {
        const w = width, h = height
        let s = index / grainCount * 2 * (w + h)
        if (s < w) return { x: s, y: 0 }
        s -= w
        if (s < h) return { x: w, y: s }
        s -= h
        if (s < w) return { x: w - s, y: h }
        s -= w
        return { x: 0, y: h - s }
    }
    Repeater {
        id: grain
        model: ring.grainCount
        Rectangle {
            required property int index
            // Set by the flicker tick: 0 or a lit level.
            property real level: 0
            width: 2; height: 2
            color: ring.ink
            opacity: Math.min(1, level + ring.flash)
            x: ring.edgePoint(index).x - 1
            y: ring.edgePoint(index).y - 1
        }
    }
    Timer {
        // About 11 ticks a second, and only while the ring is up and motion is on.
        interval: 90; repeat: true; running: ring.shown && app.motion
        onTriggered: {
            for (let i = 0; i < grain.count; i++) grain.itemAt(i).level = Math.random() < 0.3 ? 0.6 : 0
        }
    }
    // A brief second frame on the snap, larger than the ring's own border.
    Rectangle {
        anchors.fill: parent; anchors.margins: -3
        color: "transparent"
        border.width: 2; border.color: Theme.text
        opacity: ring.flash * 0.6
    }

    // The ring follows its control as the page lays out and scrolls.
    Timer {
        interval: 50; repeat: true; running: ring.shown
        onTriggered: ring.refresh()
    }

    function refresh() {
        if (!target || !target.visible || !target.enabled) { target = null; view = null; return }
        const origin = target.mapToItem(window.contentItem, 0, 0)
        geo = { x: origin.x, y: origin.y, width: target.width, height: target.height }
    }

    function within(item, region) {
        for (let p = item; p; p = p.parent) if (p === region) return true
        return false
    }
    function regionOf(item) {
        if (rail && within(item, rail)) return rail
        if (drawer && within(item, drawer)) return drawer
        return null
    }
    function centre(item) {
        return item.mapToItem(window.contentItem, item.width / 2, item.height / 2)
    }
    // A control's edges in window coordinates.
    function boxOf(item) {
        const o = item.mapToItem(window.contentItem, 0, 0)
        return { x: o.x, y: o.y, r: o.x + item.width, b: o.y + item.height }
    }
    function contains(outer, inner) {
        return outer.x <= inner.x && outer.y <= inner.y && outer.r >= inner.r && outer.b >= inner.b
    }
    // The part of an item the window shows: its box cut by every clipping ancestor.
    // Null when nothing of it is visible, so a control scrolled out of its list or
    // page cannot be a stop.
    function visibleBox(item) {
        let box = boxOf(item)
        for (let a = item.parent; a; a = a.parent) {
            if (!a.clip) continue
            const c = boxOf(a)
            box = { x: Math.max(box.x, c.x), y: Math.max(box.y, c.y), r: Math.min(box.r, c.r), b: Math.min(box.b, c.b) }
        }
        return box.r > box.x && box.b > box.y ? box : null
    }
    // ListView and GridView, the items that keep a current row.
    function isView(item) {
        return typeof item.positionViewAtIndex === "function"
    }
    // A list or grid is one candidate; its rows are reached by stepping through it.
    // Controls on a row (the three-dot buttons) are not candidates in their own right.
    function candidates(root, out) {
        for (const child of root.children) {
            if (!child.visible || !child.enabled) continue
            if (child.width <= 0 || child.height <= 0) continue
            if (isView(child)) {
                if (child.count > 0 && visibleBox(child)) out.push(child)
                continue
            }
            // Tab focus alone would miss controls that only take focus by click, such as
            // the tabs in LibraryTabs and MSegmentedControl, which keep the Tab key on
            // their selected item and move between the rest with the arrow keys.
            const focusable = child.activeFocusOnTab || ((child.focusPolicy || 0) & Qt.ClickFocus)
            // A grip only drags; the ring does not stop on it.
            const grip = child.Accessible.role === Accessible.Grip
            if (focusable && !grip && visibleBox(child)) out.push(child)
            candidates(child, out)
        }
        return out
    }
    // The top-left control, where the stick starts when nothing is selected.
    function firstTarget() {
        let best = null, bestKey = Infinity
        for (const c of candidates(scope, [])) {
            const p = centre(c)
            const key = p.y * 10000 + p.x
            if (key < bestKey) { bestKey = key; best = c }
        }
        return best
    }

    // Focus goes on with OtherFocusReason, never TabFocusReason: TrackList takes a Tab
    // focus as the Tab key arriving and moves focus into itself, which would pull
    // the ring into any list it passed over.
    function select(item) {
        if (!item) { target = null; view = null; return }
        if (isView(item)) {
            if (item.currentIndex < 0) item.currentIndex = 0
            view = item
            target = item.currentItem || item
            item.forceActiveFocus(Qt.OtherFocusReason)
        } else {
            view = null
            target = item
            item.forceActiveFocus(Qt.OtherFocusReason)
        }
        refresh()
    }

    // O inside a list returns the ring to the control it came from. Returns false
    // when the ring is not in a list, so the caller can close something else.
    function back() {
        if (!view) return false
        const o = origin
        origin = null
        if (o && o.visible && o.enabled) select(o)
        else select(firstTarget())
        return true
    }

    // Puts the ring on row `index` of the current view and scrolls it into view.
    function stepRow(index) {
        view.currentIndex = index
        view.positionViewAtIndex(index, ListView.Contain)
        target = view.currentItem || view
        // The list may sit inside a scrolling page; reveal the row through every scroller.
        if (target !== view) window.revealIn(target)
        view.forceActiveFocus(Qt.OtherFocusReason)
        refresh()
    }
    // Inside a list or grid the stick steps through its rows. A list steps up and
    // down; a grid also steps left and right, and up and down by a row of cells.
    // Returns false at the end of the view, so the ring leaves it.
    function stepInView(direction) {
        const grid = typeof view.cellWidth === "number"
        const columns = grid ? Math.max(1, Math.floor(view.width / view.cellWidth)) : 1
        let step = 0
        if (direction === "navDown") step = columns
        else if (direction === "navUp") step = -columns
        else if (grid && direction === "navRight") step = 1
        else if (grid && direction === "navLeft") step = -1
        if (!step) return false
        const next = view.currentIndex + step
        if (next < 0 || next >= view.count) return false
        stepRow(next)
        return true
    }

    // Moves the ring one control in a direction ("navUp", "navDown", "navLeft", "navRight").
    // It moves to the nearest control in the pressed direction. A control qualifies
    // when its centre lies that way. Its score is the gap between the two boxes
    // along the direction, plus twice the gap across it, so a control straight ahead
    // beats a nearer one off to the side. Measuring from edges, not centres, stops a
    // large control's centre from winning on distance.
    function move(direction) {
        if (!target || !target.visible || !target.enabled) { select(firstTarget()); return }
        if (view && stepInView(direction)) return
        const leaving = target, wasInView = view !== null
        const from = boxOf(target)
        const fromRegion = regionOf(target)
        const horizontal = direction === "navLeft" || direction === "navRight"
        const sign = direction === "navRight" || direction === "navDown" ? 1 : -1
        const fcx = (from.x + from.r) / 2, fcy = (from.y + from.b) / 2
        let best = null, bestScore = Infinity
        for (const c of candidates(scope, [])) {
            if (c === target) continue
            const box = boxOf(c)
            if (contains(box, from) || contains(from, box)) continue
            const cx = (box.x + box.r) / 2, cy = (box.y + box.b) / 2
            const along = horizontal ? (cx - fcx) * sign : (cy - fcy) * sign
            if (along <= 0) continue
            let gapAlong, gapAcross
            if (horizontal) {
                gapAlong = sign > 0 ? box.x - from.r : from.x - box.r
                gapAcross = Math.max(0, Math.max(from.y, box.y) - Math.min(from.b, box.b))
            } else {
                gapAlong = sign > 0 ? box.y - from.b : from.y - box.b
                gapAcross = Math.max(0, Math.max(from.x, box.x) - Math.min(from.r, box.r))
            }
            let score = Math.max(0, gapAlong) + 2 * gapAcross + 0.25 * Math.abs(horizontal ? cy - fcy : cx - fcx)
            // Off the page is a last resort from inside the sidebar or the drawer.
            if (fromRegion && regionOf(c) !== fromRegion) score += 100000
            if (score < bestScore) { bestScore = score; best = c }
        }
        if (best) {
            const entersList = isView(best) && !wasInView
            select(best)
            if (entersList) origin = leaving
        }
    }

    // The A button presses the control under the ring. AbstractButton has
    // click(), which is what a press does; it ignores Return, so a key event
    // would not reach it. A row in a list or grid takes Return, which the view
    // handles itself.
    function activate() {
        if (!shown) return
        if (typeof target.click === "function") target.click()
        else if (view) gamepad.sendKey(Qt.Key_Return)
    }

    // The right stick scrolls the flickable that holds the ring's control: the
    // list the row is in, or the nearest scrolling ancestor. Clamped to the content.
    // A scroller that is already at its end passes the scroll on to the one around
    // it, so a list at its last row lets the page under it move.
    function scrollBy(dy) {
        if (!shown) return
        for (let p = view || target; p; p = p.parent) {
            if (p.flickableDirection === undefined) continue
            const top = p.originY - p.topMargin
            const bottom = Math.max(top, p.originY + p.contentHeight + p.bottomMargin - p.height)
            const next = Math.max(top, Math.min(bottom, p.contentY + dy))
            if (next === p.contentY) continue
            p.cancelFlick()
            p.contentY = next
            return
        }
    }

    // A track row's own element, the one that opens its menu.
    function findRow(item) {
        if (item.track !== undefined && typeof item.menuRequested === "function") return item
        for (const c of item.children) {
            const r = findRow(c)
            if (r) return r
        }
        return null
    }
    // The triangle in a queue or history list opens the highlighted row's menu and
    // moves the ring into it. Returns false when no row is highlighted, so the
    // caller can use the triangle for something else.
    function openRowMenu() {
        if (!view || view.queueMode !== true || !target) return false
        const row = findRow(target)
        if (!row) return false
        returnView = view
        returnIndex = view.currentIndex
        row.menuRequested(row.track, row.rowIndex, row)
        // The menu lays out once it opens; the ring goes to its first item after that.
        Qt.callLater(function () { select(firstTarget()) })
        return true
    }
    // A menu closed: the ring goes back to the row that opened it.
    function leaveMenu() {
        const v = returnView, i = returnIndex
        returnView = null
        if (!v || !v.visible || i < 0 || i >= v.count) return
        view = v
        stepRow(i)
    }
}
