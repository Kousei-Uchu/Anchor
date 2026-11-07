//
//  FeedbackLoopDiagramView.swift
//  Anchor
//
//  Two kinds of diagram, both for the user's own systems metaphors, both
//  something they can literally show a clinician.
//
//  A loop is guided: say what happens first, what that leads to, and so on,
//  and the last step leads back to the first. Each link says whether more
//  leads to more or more leads to less, and the app says in plain words
//  whether the loop tends to keep itself going or to settle back.
//
//  A map is the free canvas: drag to place nodes, tap two in sequence to
//  connect them, tap a node to rename it. It is rebuilt in a later patch.
//

import SwiftUI
import SwiftData

// MARK: - Model

enum DiagramKind: String, Codable {
    case loop
    case map
}

/// Whether more of the first step leads to more of the next (`same`) or to
/// less of it (`opposite`).
enum EdgePolarity: String, Codable {
    case same
    case opposite
}

struct DiagramNode: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var label: String
    var x: Double
    var y: Double
}

struct DiagramEdge: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var fromID: UUID
    var toID: UUID
    var label: String = ""
    var polarity: EdgePolarity = .same

    enum CodingKeys: String, CodingKey {
        case id, fromID, toID, label, polarity
    }

    init(id: UUID = UUID(), fromID: UUID, toID: UUID, label: String = "", polarity: EdgePolarity = .same) {
        self.id = id
        self.fromID = fromID
        self.toID = toID
        self.label = label
        self.polarity = polarity
    }

    // Diagrams saved before loops existed have no polarity, so every field
    // added since is optional when reading.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? c.decodeIfPresent(UUID.self, forKey: .id)) ?? UUID()
        fromID = try c.decode(UUID.self, forKey: .fromID)
        toID = try c.decode(UUID.self, forKey: .toID)
        label = (try? c.decodeIfPresent(String.self, forKey: .label)) ?? ""
        polarity = (try? c.decodeIfPresent(EdgePolarity.self, forKey: .polarity)) ?? .same
    }
}

struct DiagramGraph: Codable, Equatable {
    /// 1 for diagrams saved before loops existed, 2 from Patch 26.
    var version: Int = 2
    var kind: DiagramKind = .map
    var nodes: [DiagramNode] = []
    var edges: [DiagramEdge] = []

    enum CodingKeys: String, CodingKey {
        case version, kind, nodes, edges
    }

    init(kind: DiagramKind = .map, nodes: [DiagramNode] = [], edges: [DiagramEdge] = []) {
        self.kind = kind
        self.nodes = nodes
        self.edges = edges
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        version = (try? c.decodeIfPresent(Int.self, forKey: .version)) ?? 1
        kind = (try? c.decodeIfPresent(DiagramKind.self, forKey: .kind)) ?? .map
        nodes = (try? c.decodeIfPresent([DiagramNode].self, forKey: .nodes)) ?? []
        edges = (try? c.decodeIfPresent([DiagramEdge].self, forKey: .edges)) ?? []
    }

    static func decoded(from data: Data) -> DiagramGraph {
        (try? JSONDecoder().decode(DiagramGraph.self, from: data)) ?? DiagramGraph()
    }

    func encoded() -> Data {
        (try? JSONEncoder().encode(self)) ?? Data()
    }
}

/// What a closed loop tends to do, worked out from its links: an even number
/// of "more leads to less" links (including none) keeps it going, an odd
/// number settles it back.
enum LoopCharacter {
    case reinforcing
    case balancing

    var name: String {
        switch self {
        case .reinforcing: return "Reinforcing"
        case .balancing: return "Balancing"
        }
    }

    var sentence: String {
        switch self {
        case .reinforcing: return "This one tends to keep itself going. Each time around, it adds to what it started with."
        case .balancing: return "This one tends to settle back. Each time around, it pushes against where it started."
        }
    }
}

extension DiagramGraph {
    var isClosedLoop: Bool {
        kind == .loop && nodes.count >= 2 && edges.count == nodes.count
    }

    var loopCharacter: LoopCharacter? {
        guard isClosedLoop else { return nil }
        let opposite = edges.filter { $0.polarity == .opposite }.count
        return opposite % 2 == 0 ? .reinforcing : .balancing
    }

    /// The link that leaves a step. In a loop each step has exactly one.
    func edge(from nodeID: UUID) -> DiagramEdge? {
        edges.first { $0.fromID == nodeID }
    }

    /// Rebuilds the links so each step leads to the next and the last leads
    /// back to the first. A link keeps its direction and its words when the
    /// steps around it change, because it is looked up by the step it leaves.
    mutating func relinkLoop() {
        guard nodes.count >= 2 else {
            edges = []
            placeOnRing()
            return
        }
        let previous = Dictionary(edges.map { ($0.fromID, $0) }, uniquingKeysWith: { first, _ in first })
        var rebuilt: [DiagramEdge] = []
        for (index, node) in nodes.enumerated() {
            let next = nodes[(index + 1) % nodes.count]
            var edge = previous[node.id] ?? DiagramEdge(fromID: node.id, toID: next.id)
            edge.toID = next.id
            rebuilt.append(edge)
        }
        edges = rebuilt
        placeOnRing()
    }

    /// Positions on a nominal ring, so a loop still draws sensibly if it is
    /// ever opened as a free map.
    mutating func placeOnRing() {
        let count = nodes.count
        for index in nodes.indices {
            let angle = -Double.pi / 2 + 2 * Double.pi * Double(index) / Double(max(count, 1))
            nodes[index].x = 180 + 120 * cos(angle)
            nodes[index].y = 180 + 120 * sin(angle)
        }
    }

    /// A ready-made loop, used by the demo data.
    static func loop(_ steps: [(label: String, polarity: EdgePolarity)]) -> DiagramGraph {
        var graph = DiagramGraph(kind: .loop)
        graph.nodes = steps.map { DiagramNode(label: $0.label, x: 0, y: 0) }
        graph.relinkLoop()
        for index in graph.edges.indices where index < steps.count {
            graph.edges[index].polarity = steps[index].polarity
        }
        return graph
    }
}

// MARK: - List

struct FeedbackLoopDiagramListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var diagrams: [FeedbackLoopDiagram]
    @State private var openedDiagram: FeedbackLoopDiagram?
    @State private var justCreatedID: UUID?

    var body: some View {
        Group {
            if diagrams.isEmpty {
                ScrollView {
                    VStack(spacing: 12) {
                        Anchor.EmptyState(
                            icon: "arrow.triangle.2.circlepath",
                            title: "No diagrams yet",
                            message: "Draw how things feed into each other, in your own words, to show someone else. A loop is the place to start.",
                            actionTitle: "New loop",
                            tint: Anchor.Theme.sage
                        ) { addDiagram(kind: .loop) }
                        Button("Or draw a free map instead") { addDiagram(kind: .map) }
                            .font(.footnote)
                    }
                    .padding()
                }
            } else {
                List {
                    ForEach(diagrams) { diagram in
                        Button { openedDiagram = diagram } label: {
                            Anchor.Card(accentColor: Anchor.Theme.sage) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(diagram.title.isEmpty ? "Untitled" : diagram.title)
                                            .font(.system(.headline, design: .rounded))
                                            .foregroundStyle(.primary)
                                        Text(summary(for: diagram))
                                            .font(.footnote)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.tertiary)
                                }
                                .contentShape(Rectangle())
                            }
                        }
                        .buttonStyle(.plain)
                        .anchorDeletable { modelContext.delete(diagram) }
                        .anchorCardRow()
                    }
                }
                .listStyle(.plain)
            }
        }
        .anchorBackground()
        .navigationTitle("Feedback-loop diagrams")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button("New loop") { addDiagram(kind: .loop) }
                    Button("New map") { addDiagram(kind: .map) }
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("New diagram")
            }
        }
        .navigationDestination(item: $openedDiagram) { diagram in
            FeedbackLoopDiagramView(diagram: diagram, startsInEditor: justCreatedID == diagram.id)
        }
    }

    /// One plain line under the title: what kind it is and, for a closed
    /// loop, what it tends to do. Nothing is counted or scored.
    private func summary(for diagram: FeedbackLoopDiagram) -> String {
        let graph = DiagramGraph.decoded(from: diagram.graphJSON)
        switch graph.kind {
        case .loop:
            if let character = graph.loopCharacter {
                return "Loop, \(character.name.lowercased())"
            }
            return "Loop, not closed yet"
        case .map:
            if graph.nodes.isEmpty { return "Map, nothing drawn yet" }
            return "Map, \(graph.nodes.count) \(graph.nodes.count == 1 ? "item" : "items")"
        }
    }

    /// A new diagram opens straight away, ready to be drawn on. A new loop
    /// opens with its editor already up, because there is nothing to look at.
    private func addDiagram(kind: DiagramKind) {
        let data = DiagramGraph(kind: kind).encoded()
        let new = FeedbackLoopDiagram(title: kind == .loop ? "New loop" : "New diagram", graphJSON: data)
        modelContext.insert(new)
        justCreatedID = kind == .loop ? new.id : nil
        openedDiagram = new
    }
}

// MARK: - Looking at a diagram

/// A diagram as something to look at (and show a clinician): nothing
/// draggable. Dragging and tapping can't share a screen with just looking, so
/// this keeps a plain Edit button that opens the editor for its kind.
struct FeedbackLoopDiagramView: View {
    @Bindable var diagram: FeedbackLoopDiagram
    var startsInEditor: Bool = false
    @State private var showingEditor = false
    @State private var didAutoOpen = false

    private var graph: DiagramGraph {
        DiagramGraph.decoded(from: diagram.graphJSON)
    }

    var body: some View {
        Group {
            if graph.kind == .loop {
                LoopReadView(graph: graph)
            } else {
                mapBody
            }
        }
        .anchorBackground()
        .navigationTitle(diagram.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Edit") { showingEditor = true }
            }
        }
        .onAppear {
            if startsInEditor && !didAutoOpen {
                didAutoOpen = true
                showingEditor = true
            }
        }
        .sheet(isPresented: $showingEditor) {
            if graph.kind == .loop {
                Anchor.ItemEditorSheet(title: "Edit loop") {
                    FeedbackLoopBuilderView(diagram: diagram)
                }
            } else {
                Anchor.ItemEditorSheet(title: "Edit diagram") {
                    FeedbackLoopDiagramEditorView(diagram: diagram)
                }
            }
        }
    }

    private var mapBody: some View {
        let graph = self.graph
        return ZStack {
            Canvas { context, size in
                for edge in graph.edges {
                    guard let from = graph.nodes.first(where: { $0.id == edge.fromID }),
                          let to = graph.nodes.first(where: { $0.id == edge.toID }) else { continue }
                    var path = Path()
                    path.move(to: CGPoint(x: from.x, y: from.y))
                    path.addLine(to: CGPoint(x: to.x, y: to.y))
                    context.stroke(path, with: .color(Anchor.Theme.accent.opacity(0.5)), lineWidth: 2)
                }
            }
            .allowsHitTesting(false)

            ForEach(graph.nodes) { node in
                Text(node.label)
                    .font(.system(.caption, design: .rounded).weight(.medium))
                    .padding(10)
                    .background(Anchor.Theme.sageSoft, in: RoundedRectangle(cornerRadius: 10))
                    .position(x: node.x, y: node.y)
            }

            if graph.nodes.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "point.3.connected.trianglepath.dotted")
                        .font(.largeTitle)
                        .foregroundStyle(.tertiary)
                    Text("Nothing drawn yet. Tap Edit to add your first node.")
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// A loop to look at: the ring, then a plain-words reading of it.
struct LoopReadView: View {
    let graph: DiagramGraph

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if graph.nodes.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.largeTitle)
                            .foregroundStyle(.tertiary)
                        Text("Nothing here yet. Tap Edit and write what happens first.")
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 60)
                } else {
                    LoopRingView(graph: graph)
                        .frame(height: 380)
                    readingCard
                }
            }
            .padding()
        }
    }

    private var readingCard: some View {
        Anchor.Card(accentColor: Anchor.Theme.sage) {
            VStack(alignment: .leading, spacing: 12) {
                if let character = graph.loopCharacter {
                    Text(character.name)
                        .font(.system(.headline, design: .rounded))
                    Text(character.sentence)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Not a loop yet")
                        .font(.system(.headline, design: .rounded))
                    Text("Add another step. The last step leads back to the first.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                if graph.isClosedLoop {
                    Divider()
                    ForEach(Array(graph.nodes.enumerated()), id: \.element.id) { index, node in
                        let next = graph.nodes[(index + 1) % graph.nodes.count]
                        let edge = graph.edge(from: node.id)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(name(of: node)) leads to \(name(of: next)). \(edge?.polarity == .opposite ? "More leads to less." : "More leads to more.")")
                                .font(.subheadline)
                            if let how = edge?.label, !how.isEmpty {
                                Text(how)
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    Text("A plus on an arrow means more leads to more. A minus means more leads to less.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func name(of node: DiagramNode) -> String {
        node.label.isEmpty ? "A step" : node.label
    }
}

/// The ring itself. Steps sit evenly round a circle, clockwise from the top,
/// with an arrow from each to the next and a plus or minus on each arrow.
struct LoopRingView: View {
    let graph: DiagramGraph

    var body: some View {
        GeometryReader { geo in
            let count = graph.nodes.count
            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
            let radius = max(60.0, Double(min(geo.size.width, geo.size.height)) / 2 - 78)
            ZStack {
                if count >= 2 {
                    Canvas { context, _ in
                        drawArrows(into: &context, count: count, center: center, radius: radius)
                    }
                    .allowsHitTesting(false)
                }

                ForEach(Array(graph.nodes.enumerated()), id: \.element.id) { index, node in
                    nodeLabel(node)
                        .position(point(angle(index, count), center: center, radius: radius))
                }

                if count >= 2 {
                    ForEach(Array(graph.nodes.enumerated()), id: \.element.id) { index, node in
                        let middle = angle(index, count) + Double.pi / Double(count)
                        let edge = graph.edge(from: node.id)
                        badge(edge?.polarity ?? .same)
                            .position(point(middle, center: center, radius: radius))
                        if let how = edge?.label, !how.isEmpty {
                            Text(how)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                                .frame(maxWidth: 90)
                                .position(point(middle, center: center, radius: radius + 34))
                        }
                    }
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilitySummary)
    }

    private func angle(_ index: Int, _ count: Int) -> Double {
        -Double.pi / 2 + 2 * Double.pi * Double(index) / Double(max(count, 1))
    }

    private func point(_ angle: Double, center: CGPoint, radius: Double) -> CGPoint {
        CGPoint(x: center.x + CGFloat(radius * cos(angle)),
                y: center.y + CGFloat(radius * sin(angle)))
    }

    private func drawArrows(into context: inout GraphicsContext, count: Int, center: CGPoint, radius: Double) {
        let step = 2 * Double.pi / Double(count)
        // Leave room at each end for the step's box, a little less on a
        // crowded ring.
        let inset = min(40.0 / radius, step * 0.32)
        for index in 0..<count {
            let start = angle(index, count) + inset
            let end = angle(index, count) + step - inset
            var path = Path()
            let samples = 24
            for sample in 0...samples {
                let a = start + (end - start) * Double(sample) / Double(samples)
                let p = point(a, center: center, radius: radius)
                if sample == 0 { path.move(to: p) } else { path.addLine(to: p) }
            }
            context.stroke(path, with: .color(Anchor.Theme.accent.opacity(0.6)), lineWidth: 2)

            // Going clockwise on screen, the direction of travel at angle a
            // is (-sin a, cos a).
            let tip = point(end, center: center, radius: radius)
            let direction = CGPoint(x: CGFloat(-sin(end)), y: CGFloat(cos(end)))
            context.fill(arrowHead(tip: tip, direction: direction), with: .color(Anchor.Theme.accent.opacity(0.8)))
        }
    }

    private func arrowHead(tip: CGPoint, direction: CGPoint) -> Path {
        let size: CGFloat = 11
        func rotated(_ v: CGPoint, by angle: Double) -> CGPoint {
            CGPoint(x: v.x * CGFloat(cos(angle)) - v.y * CGFloat(sin(angle)),
                    y: v.x * CGFloat(sin(angle)) + v.y * CGFloat(cos(angle)))
        }
        let left = rotated(direction, by: Double.pi * 5 / 6)
        let right = rotated(direction, by: -Double.pi * 5 / 6)
        var path = Path()
        path.move(to: tip)
        path.addLine(to: CGPoint(x: tip.x + left.x * size, y: tip.y + left.y * size))
        path.addLine(to: CGPoint(x: tip.x + right.x * size, y: tip.y + right.y * size))
        path.closeSubpath()
        return path
    }

    private func nodeLabel(_ node: DiagramNode) -> some View {
        Text(node.label.isEmpty ? "Step" : node.label)
            .font(.system(.footnote, design: .rounded).weight(.medium))
            .multilineTextAlignment(.center)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .frame(maxWidth: 120)
            .background(Anchor.Theme.sageSoft, in: RoundedRectangle(cornerRadius: 12))
    }

    private func badge(_ polarity: EdgePolarity) -> some View {
        Text(polarity == .same ? "+" : "\u{2212}")
            .font(.system(.footnote, design: .rounded).weight(.bold))
            .foregroundStyle(Anchor.Theme.accent)
            .frame(width: 24, height: 24)
            .background(Circle().fill(Anchor.Theme.accentSoft))
    }

    private var accessibilitySummary: String {
        let names = graph.nodes.map { $0.label.isEmpty ? "a step" : $0.label }
        guard names.count >= 2 else { return "Loop with \(names.count) \(names.count == 1 ? "step" : "steps"), not closed yet." }
        let character = graph.loopCharacter.map { " \($0.name)." } ?? ""
        return "Loop of \(names.count) steps: \(names.joined(separator: ", ")), then back to \(names[0]).\(character)"
    }
}

// MARK: - Building a loop

/// The guided editor for a loop: one row per step, in order, each saying how
/// it leads to the next. Typing and reordering never share a gesture with
/// drawing, so there is nothing to disambiguate.
struct FeedbackLoopBuilderView: View {
    @Bindable var diagram: FeedbackLoopDiagram
    @State private var graph = DiagramGraph(kind: .loop)
    @State private var newStep = ""
    @State private var editMode: EditMode = .inactive
    @FocusState private var addFocused: Bool
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        List {
            Section("Name") {
                TextField("Name this loop", text: $diagram.title)
            }

            Section {
                ForEach($graph.nodes) { $node in
                    stepRow($node)
                }
                .onDelete(perform: deleteSteps)
                .onMove(perform: moveSteps)

                HStack {
                    TextField(graph.nodes.isEmpty ? "What happens first?" : "What does that lead to?", text: $newStep)
                        .focused($addFocused)
                        .submitLabel(.next)
                        .onSubmit(addStep)
                    Button("Add", action: addStep)
                        .disabled(newStep.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            } header: {
                Text("Steps, in order")
            } footer: {
                Text(graph.nodes.count < 2
                     ? "A loop needs at least two steps. The last one leads back to the first."
                     : "The last step leads back to the first.")
            }

            if let character = graph.loopCharacter {
                Section("How it reads") {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(character.name)
                            .font(.system(.headline, design: .rounded))
                        Text(character.sentence)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .environment(\.editMode, $editMode)
        .toolbar {
            if graph.nodes.count > 1 {
                ToolbarItem(placement: .topBarLeading) {
                    Anchor.ReorderToolbarButton()
                }
            }
        }
        .onAppear {
            var loaded = DiagramGraph.decoded(from: diagram.graphJSON)
            loaded.kind = .loop
            graph = loaded
        }
        .onChange(of: graph) { _, new in
            save(new)
        }
        .onDisappear {
            // Steps left blank are dropped when the editor closes.
            var cleaned = graph
            cleaned.nodes.removeAll { $0.label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            if cleaned.nodes.count != graph.nodes.count {
                cleaned.relinkLoop()
                save(cleaned)
            }
        }
    }

    private func stepRow(_ node: Binding<DiagramNode>) -> some View {
        let id = node.wrappedValue.id
        let hasLink = graph.edge(from: id) != nil
        let isLast = graph.nodes.last?.id == id
        return VStack(alignment: .leading, spacing: 10) {
            TextField("What happens", text: node.label, axis: .vertical)
            if hasLink {
                Text(isLast ? "That leads back to the first step" : "That leads to the next step")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                polarityPicker(for: id)
                TextField("How, in your words (optional)", text: howBinding(for: id))
                    .font(.footnote)
            }
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private func polarityPicker(for id: UUID) -> some View {
        if typeSize.isAccessibilitySize {
            Picker("Direction", selection: polarityBinding(for: id)) {
                Text("More leads to more").tag(EdgePolarity.same)
                Text("More leads to less").tag(EdgePolarity.opposite)
            }
            .pickerStyle(.menu)
        } else {
            Picker("Direction", selection: polarityBinding(for: id)) {
                Text("More leads to more").tag(EdgePolarity.same)
                Text("More leads to less").tag(EdgePolarity.opposite)
            }
            .pickerStyle(.segmented)
        }
    }

    private func polarityBinding(for id: UUID) -> Binding<EdgePolarity> {
        Binding(
            get: { graph.edge(from: id)?.polarity ?? .same },
            set: { value in
                if let index = graph.edges.firstIndex(where: { $0.fromID == id }) {
                    graph.edges[index].polarity = value
                }
            }
        )
    }

    private func howBinding(for id: UUID) -> Binding<String> {
        Binding(
            get: { graph.edge(from: id)?.label ?? "" },
            set: { value in
                if let index = graph.edges.firstIndex(where: { $0.fromID == id }) {
                    graph.edges[index].label = value
                }
            }
        )
    }

    private func addStep() {
        let text = newStep.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        graph.nodes.append(DiagramNode(label: text, x: 0, y: 0))
        graph.relinkLoop()
        newStep = ""
        addFocused = true
    }

    private func deleteSteps(at offsets: IndexSet) {
        graph.nodes.remove(atOffsets: offsets)
        graph.relinkLoop()
    }

    private func moveSteps(from source: IndexSet, to destination: Int) {
        graph.nodes.move(fromOffsets: source, toOffset: destination)
        graph.relinkLoop()
    }

    /// Writes the loop back to the diagram, but only when something changed,
    /// so opening the editor does not move the diagram up the list.
    private func save(_ new: DiagramGraph) {
        var toSave = new
        toSave.version = 2
        toSave.kind = .loop
        if toSave != DiagramGraph.decoded(from: diagram.graphJSON) {
            diagram.graphJSON = toSave.encoded()
            diagram.lastEditedAt = .now
        }
    }
}

// MARK: - Editing a free map

// Redesign note: the previous version stacked a plain `DragGesture()`, an
// `.onTapGesture`, and an `.onLongPressGesture` all on the very same node
// view with no priority between them, plus a *separate* background
// tap-to-add-node gesture underneath a non-interactive `Canvas`. SwiftUI
// doesn't reliably arbitrate three overlapping recognizers like that — in
// practice the zero-distance drag gesture wins almost every touch, so taps
// (to connect nodes) and long-presses (to rename) barely fired, and adding
// nodes was inconsistent. Rather than fight SwiftUI's gesture-priority
// rules to get that exactly right without a device to test on, the
// interaction model is restructured so drag and tap are never candidates
// for the same touch at the same time:
//   - Adding a node is an explicit toolbar button (a fixed action, not a
//     background tap that has to be distinguished from everything else).
//   - "Connect mode" is an explicit toggle. While it's off, dragging moves
//     nodes and a plain tap opens rename/delete. While it's on, dragging is
//     disabled and tapping two nodes in sequence connects them. The two
//     behaviors are never live at the same time, so there's nothing left
//     to disambiguate.
struct FeedbackLoopDiagramEditorView: View {
    @Bindable var diagram: FeedbackLoopDiagram
    @State private var graph = DiagramGraph()
    @State private var pendingEdgeStart: UUID?
    @State private var isConnectMode = false
    @State private var renamingNode: DiagramNode?
    @State private var renameText = ""

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Anchor.Theme.background(.light).ignoresSafeArea()

                Canvas { context, size in
                    for edge in graph.edges {
                        guard let from = graph.nodes.first(where: { $0.id == edge.fromID }),
                              let to = graph.nodes.first(where: { $0.id == edge.toID }) else { continue }
                        var path = Path()
                        path.move(to: CGPoint(x: from.x, y: from.y))
                        path.addLine(to: CGPoint(x: to.x, y: to.y))
                        context.stroke(path, with: .color(Anchor.Theme.accent.opacity(0.5)), lineWidth: 2)
                    }
                }
                .allowsHitTesting(false)

                ForEach(graph.nodes) { node in
                    nodeView(node, canvasSize: geo.size)
                        .position(x: node.x, y: node.y)
                }

                if graph.nodes.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "point.3.connected.trianglepath.dotted")
                            .font(.largeTitle)
                            .foregroundStyle(.tertiary)
                        Text("Tap + to add your first node")
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .navigationTitle(diagram.title)
        .toolbar {
            ToolbarItem(placement: .principal) {
                TextField("Title", text: $diagram.title)
                    .multilineTextAlignment(.center)
            }
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                Button {
                    withAnimation { isConnectMode.toggle() }
                    pendingEdgeStart = nil
                } label: {
                    Label("Connect", systemImage: isConnectMode ? "link.circle.fill" : "link.circle")
                }
                .tint(isConnectMode ? Anchor.Theme.accent : nil)

                Button {
                    addNode()
                } label: {
                    Label("Add node", systemImage: "plus.circle.fill")
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            if isConnectMode {
                Text(pendingEdgeStart == nil ? "Tap a node to start a connection" : "Now tap the node to connect it to")
                    .font(.caption)
                    .padding(8)
                    .frame(maxWidth: .infinity)
                    .background(.thinMaterial)
            }
        }
        .onAppear {
            graph = (try? JSONDecoder().decode(DiagramGraph.self, from: diagram.graphJSON)) ?? DiagramGraph()
        }
        .onChange(of: graph) { _, newValue in
            diagram.graphJSON = (try? JSONEncoder().encode(newValue)) ?? diagram.graphJSON
            diagram.lastEditedAt = .now
        }
        .alert("Rename or delete node", isPresented: Binding(get: { renamingNode != nil }, set: { if !$0 { renamingNode = nil } })) {
            TextField("Label", text: $renameText)
            Button("Save") {
                if let node = renamingNode, let index = graph.nodes.firstIndex(where: { $0.id == node.id }) {
                    graph.nodes[index].label = renameText
                }
                renamingNode = nil
            }
            Button("Delete node", role: .destructive) {
                if let node = renamingNode {
                    graph.nodes.removeAll { $0.id == node.id }
                    graph.edges.removeAll { $0.fromID == node.id || $0.toID == node.id }
                }
                renamingNode = nil
            }
            Button("Cancel", role: .cancel) { renamingNode = nil }
        }
    }

    @ViewBuilder
    private func nodeView(_ node: DiagramNode, canvasSize: CGSize) -> some View {
        let label = Text(node.label)
            .font(.system(.caption, design: .rounded).weight(.medium))
            .padding(10)
            .background(
                pendingEdgeStart == node.id ? Anchor.Theme.accentSoft : Anchor.Theme.sageSoft,
                in: RoundedRectangle(cornerRadius: 10)
            )

        // Branching the whole view (rather than passing an optional
        // Gesture into a single `.gesture()` call) is what actually
        // guarantees only one recognizer exists at a time — an optional
        // Gesture doesn't type-check cleanly across DragGesture/TapGesture,
        // and more importantly, keeping both attached-but-conditionally-
        // no-op would still leave two live recognizers fighting over the
        // same touch, which was the original bug.
        if isConnectMode {
            label
                .onTapGesture {
                    if let start = pendingEdgeStart, start != node.id {
                        graph.edges.append(DiagramEdge(fromID: start, toID: node.id))
                        pendingEdgeStart = nil
                    } else {
                        pendingEdgeStart = node.id
                    }
                }
        } else {
            // Rename lives on a small dedicated button rather than a plain
            // tap on the node itself — a real Button reliably takes tap
            // priority over a parent's DragGesture in SwiftUI for its own
            // bounds, whereas two raw gesture recognizers on the exact same
            // view (the original bug) do not reliably arbitrate.
            label
                .overlay(alignment: .topTrailing) {
                    Button {
                        renameText = node.label
                        renamingNode = node
                    } label: {
                        Image(systemName: "pencil.circle.fill")
                            .font(.caption)
                            .foregroundStyle(Anchor.Theme.accent)
                            .background(Circle().fill(.white))
                    }
                    .buttonStyle(.plain)
                    .offset(x: 8, y: -8)
                }
                .gesture(
                    DragGesture(minimumDistance: 2)
                        .onChanged { value in
                            if let index = graph.nodes.firstIndex(where: { $0.id == node.id }) {
                                graph.nodes[index].x = min(max(value.location.x, 24), canvasSize.width - 24)
                                graph.nodes[index].y = min(max(value.location.y, 24), canvasSize.height - 24)
                            }
                        }
                )
        }
    }

    private func addNode() {
        // Staggered default placement so new nodes don't all land on top of
        // each other; the user can immediately drag to reposition.
        let offset = Double(graph.nodes.count % 5) * 20
        graph.nodes.append(DiagramNode(label: "New", x: 120 + offset, y: 160 + offset))
    }
}
