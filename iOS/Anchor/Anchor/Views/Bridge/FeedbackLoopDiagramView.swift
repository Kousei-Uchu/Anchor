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
    /// A link on a free map that carries no sign. Loops never use this.
    case none
}

/// The soft fill behind an item on a free map.
enum NodeColour: String, Codable, CaseIterable, Identifiable {
    case sage, rose, amber, sky, lilac, stone

    var id: String { rawValue }
    var name: String { rawValue.capitalized }

    var fill: Color {
        switch self {
        case .sage: return Anchor.Theme.sageSoft
        case .rose: return Color(red: 0.86, green: 0.40, blue: 0.48).opacity(0.28)
        case .amber: return Color(red: 0.93, green: 0.66, blue: 0.20).opacity(0.30)
        case .sky: return Color(red: 0.30, green: 0.60, blue: 0.88).opacity(0.28)
        case .lilac: return Color(red: 0.62, green: 0.48, blue: 0.85).opacity(0.28)
        case .stone: return Color.gray.opacity(0.25)
        }
    }
}

struct DiagramNode: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var label: String
    var x: Double
    var y: Double
    /// Free maps only. Nothing set means the default sage.
    var colour: NodeColour? = nil
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
    // added since is optional when reading. A map link with no sign saved
    // reads back as no sign, so old maps do not suddenly show plus marks.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? c.decodeIfPresent(UUID.self, forKey: .id)) ?? UUID()
        fromID = try c.decode(UUID.self, forKey: .fromID)
        toID = try c.decode(UUID.self, forKey: .toID)
        label = (try? c.decodeIfPresent(String.self, forKey: .label)) ?? ""
        polarity = (try? c.decodeIfPresent(EdgePolarity.self, forKey: .polarity)) ?? .none
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
    mutating func placeOnRing(radius: Double = 120) {
        let count = nodes.count
        let middle = radius + 60
        for index in nodes.indices {
            let angle = -Double.pi / 2 + 2 * Double.pi * Double(index) / Double(max(count, 1))
            nodes[index].x = middle + radius * cos(angle)
            nodes[index].y = middle + radius * sin(angle)
        }
    }

    /// Turns a loop into a free map. The steps keep their order, links and
    /// signs, and are spread on a ring wide enough for the boxes not to touch.
    func asMap() -> DiagramGraph {
        var map = self
        map.kind = .map
        map.version = 2
        map.placeOnRing(radius: max(120, 30 * Double(nodes.count)))
        return map
    }

    /// A ready-made map, used by the demo data.
    static func demoMap() -> DiagramGraph {
        var graph = DiagramGraph(kind: .map)
        let names = ["A hard day", "I shut down", "I skip the things that help", "Everything piles up"]
        let spots: [(Double, Double)] = [(120, 80), (320, 80), (320, 240), (120, 240)]
        for (index, name) in names.enumerated() {
            graph.nodes.append(DiagramNode(label: name, x: spots[index].0, y: spots[index].1))
        }
        graph.nodes[1].colour = .sky
        graph.nodes[3].colour = .rose
        for index in 0..<3 {
            graph.edges.append(DiagramEdge(fromID: graph.nodes[index].id, toID: graph.nodes[index + 1].id, polarity: .same))
        }
        graph.edges.append(DiagramEdge(fromID: graph.nodes[3].id, toID: graph.nodes[0].id, label: "the next day is harder", polarity: .same))
        return graph
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
    @State private var showingTemplates = false
    @State private var pendingFromTemplate: FeedbackLoopDiagram?

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
                        Button("Or start from a template") { showingTemplates = true }
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
        .guideButton("bridge.feedback-loops", tab: .bridge)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button("New loop") { addDiagram(kind: .loop) }
                    Button("New map") { addDiagram(kind: .map) }
                    Button("From a template") { showingTemplates = true }
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("New diagram")
            }
        }
        .navigationDestination(item: $openedDiagram) { diagram in
            FeedbackLoopDiagramView(diagram: diagram, startsInEditor: justCreatedID == diagram.id)
        }
        .sheet(isPresented: $showingTemplates, onDismiss: {
            // Open the new diagram only once the picker has gone, so the
            // two do not fight over the screen.
            if let made = pendingFromTemplate {
                pendingFromTemplate = nil
                openedDiagram = made
            }
        }) {
            DiagramTemplatePickerView { template in
                addDiagram(from: template)
            }
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

    /// A copy of a template becomes the person's own diagram. Nothing links
    /// it back to the template, so changing it later changes only the copy.
    private func addDiagram(from template: DiagramTemplate) {
        let new = FeedbackLoopDiagram(title: template.name, graphJSON: template.build().encoded())
        modelContext.insert(new)
        justCreatedID = nil
        pendingFromTemplate = new
        showingTemplates = false
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
    @State private var confirmingMap = false
    @State private var showingShare = false

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
        .guideButton("bridge.feedback-loops", tab: .bridge)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if !graph.nodes.isEmpty {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            showingShare = true
                        } label: {
                            Label("Share as picture or PDF", systemImage: "square.and.arrow.up")
                        }
                        .hiddenInShowcase()
                        if graph.kind == .loop {
                            Button("Open as a free map") { confirmingMap = true }
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                    .accessibilityLabel("More")
                }
            }
            ToolbarItem(placement: .primaryAction) {
                Button("Edit") { showingEditor = true }
            }
        }
        .confirmationDialog("Open this loop as a free map?", isPresented: $confirmingMap, titleVisibility: .visible) {
            Button("Open as a map") {
                diagram.graphJSON = graph.asMap().encoded()
                diagram.lastEditedAt = .now
            }
            Button("Keep the loop", role: .cancel) {}
        } message: {
            Text("You can then move things around and add more, but it will not be a loop any more.")
        }
        .onAppear {
            if startsInEditor && !didAutoOpen {
                didAutoOpen = true
                showingEditor = true
            }
        }
        .sheet(isPresented: $showingShare) {
            DiagramShareView(title: diagram.title, graph: graph)
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
        MapReadView(graph: graph)
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
                        badge(edge?.polarity == .opposite ? .opposite : .same)
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
        Text(polarity == .opposite ? "\u{2212}" : "+")
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
            get: { graph.edge(from: id)?.polarity == .opposite ? .opposite : .same },
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

// MARK: - Free map: drawing

/// The sums shared by looking at a map and editing one. A map lives in its
/// own coordinates; `pan` and `zoom` turn them into screen points.
enum MapGeometry {
    static let halfWidth: CGFloat = 56
    static let halfHeight: CGFloat = 30
    static let minZoom: CGFloat = 0.25
    static let maxZoom: CGFloat = 2.5

    static func screen(_ node: DiagramNode, pan: CGSize, zoom: CGFloat) -> CGPoint {
        CGPoint(x: CGFloat(node.x) * zoom + pan.width, y: CGFloat(node.y) * zoom + pan.height)
    }

    /// The visible part of a link: from the edge of one box to the edge of
    /// the other, nudged sideways so a pair of links in opposite directions
    /// do not sit on top of each other.
    static func segment(from a: CGPoint, to b: CGPoint, scale: CGFloat) -> (start: CGPoint, end: CGPoint)? {
        let dx = b.x - a.x
        let dy = b.y - a.y
        let length = (dx * dx + dy * dy).squareRoot()
        guard length > 1 else { return nil }
        let ux = dx / length
        let uy = dy / length
        let hw = halfWidth * scale + 4
        let hh = halfHeight * scale + 4
        let tx: CGFloat = abs(ux) > 0.001 ? hw / abs(ux) : CGFloat.infinity
        let ty: CGFloat = abs(uy) > 0.001 ? hh / abs(uy) : CGFloat.infinity
        let t = min(tx, ty)
        guard t * 2 < length else { return nil }
        let ox = -uy * 6 * scale
        let oy = ux * 6 * scale
        return (CGPoint(x: a.x + ux * t + ox, y: a.y + uy * t + oy),
                CGPoint(x: b.x - ux * t + ox, y: b.y - uy * t + oy))
    }

    /// A pan and zoom that fit everything on a map into `size`.
    static func fit(_ graph: DiagramGraph, in size: CGSize, maxFitZoom: CGFloat) -> (pan: CGSize, zoom: CGFloat) {
        guard !graph.nodes.isEmpty, size.width > 0, size.height > 0 else { return (CGSize.zero, 1) }
        let xs = graph.nodes.map { $0.x }
        let ys = graph.nodes.map { $0.y }
        let minX = xs.min() ?? 0
        let maxX = xs.max() ?? 0
        let minY = ys.min() ?? 0
        let maxY = ys.max() ?? 0
        let width = CGFloat(maxX - minX) + halfWidth * 2 + 48
        let height = CGFloat(maxY - minY) + halfHeight * 2 + 48
        let z = min(max(min(size.width / width, size.height / height), minZoom), maxFitZoom)
        let cx = CGFloat((minX + maxX) / 2)
        let cy = CGFloat((minY + maxY) / 2)
        return (CGSize(width: size.width / 2 - cx * z, height: size.height / 2 - cy * z), z)
    }

    static func drawEdges(into context: inout GraphicsContext, graph: DiagramGraph, pan: CGSize, zoom: CGFloat) {
        var lookup: [UUID: DiagramNode] = [:]
        for node in graph.nodes { lookup[node.id] = node }
        let colour = Anchor.Theme.accent.opacity(0.65)
        for edge in graph.edges {
            guard let from = lookup[edge.fromID], let to = lookup[edge.toID],
                  let seg = segment(from: screen(from, pan: pan, zoom: zoom),
                                    to: screen(to, pan: pan, zoom: zoom),
                                    scale: zoom) else { continue }
            var path = Path()
            path.move(to: seg.start)
            path.addLine(to: seg.end)
            context.stroke(path, with: .color(colour), lineWidth: 2)

            let dx = seg.end.x - seg.start.x
            let dy = seg.end.y - seg.start.y
            let length = max((dx * dx + dy * dy).squareRoot(), 1)
            let direction = CGPoint(x: dx / length, y: dy / length)
            context.fill(arrowHead(tip: seg.end, direction: direction, size: 10 * max(zoom, 0.8)),
                         with: .color(colour))
        }
    }

    static func arrowHead(tip: CGPoint, direction: CGPoint, size: CGFloat) -> Path {
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
}

/// The links of a map: lines and arrowheads, plus a plus or minus and the
/// user's words on the links that have them. Never takes a touch.
struct MapLayer: View {
    let graph: DiagramGraph
    let pan: CGSize
    let zoom: CGFloat

    var body: some View {
        let lookup = Dictionary(graph.nodes.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        ZStack {
            Canvas { context, _ in
                MapGeometry.drawEdges(into: &context, graph: graph, pan: pan, zoom: zoom)
            }
            ForEach(graph.edges) { edge in
                if let from = lookup[edge.fromID], let to = lookup[edge.toID],
                   let seg = MapGeometry.segment(from: MapGeometry.screen(from, pan: pan, zoom: zoom),
                                                 to: MapGeometry.screen(to, pan: pan, zoom: zoom),
                                                 scale: zoom) {
                    let mid = CGPoint(x: (seg.start.x + seg.end.x) / 2, y: (seg.start.y + seg.end.y) / 2)
                    let markScale = max(zoom, 0.6)
                    if edge.polarity != .none {
                        SignBadge(polarity: edge.polarity)
                            .scaleEffect(markScale)
                            .position(mid)
                    }
                    if !edge.label.isEmpty {
                        Text(edge.label)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: 100)
                            .scaleEffect(markScale)
                            .position(x: mid.x, y: mid.y + 20 * markScale)
                    }
                }
            }
        }
        .allowsHitTesting(false)
    }
}

struct SignBadge: View {
    let polarity: EdgePolarity

    var body: some View {
        Text(polarity == .opposite ? "\u{2212}" : "+")
            .font(.system(.footnote, design: .rounded).weight(.bold))
            .foregroundStyle(Anchor.Theme.accent)
            .frame(width: 24, height: 24)
            .background(Circle().fill(Anchor.Theme.accentSoft))
    }
}

struct MapNodeLabel: View {
    let node: DiagramNode
    var highlighted: Bool = false

    var body: some View {
        Text(node.label.isEmpty ? "Item" : node.label)
            .font(.system(.footnote, design: .rounded).weight(.medium))
            .multilineTextAlignment(.center)
            .lineLimit(3)
            .padding(.horizontal, 8)
            .padding(.vertical, 8)
            .frame(width: MapGeometry.halfWidth * 2)
            .background((node.colour ?? .sage).fill, in: RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Anchor.Theme.accent, lineWidth: highlighted ? 2 : 0)
            )
    }
}

// MARK: - Free map: looking at one

/// A map to look at, scaled to fit the screen. Editing is where you pan and
/// zoom.
struct MapReadView: View {
    let graph: DiagramGraph

    var body: some View {
        GeometryReader { geo in
            let fit = MapGeometry.fit(graph, in: geo.size, maxFitZoom: 1.3)
            ZStack {
                MapLayer(graph: graph, pan: fit.pan, zoom: fit.zoom)
                ForEach(graph.nodes) { node in
                    MapNodeLabel(node: node)
                        .scaleEffect(fit.zoom)
                        .position(MapGeometry.screen(node, pan: fit.pan, zoom: fit.zoom))
                }
                if graph.nodes.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "point.3.connected.trianglepath.dotted")
                            .font(.largeTitle)
                            .foregroundStyle(.tertiary)
                        Text("Nothing drawn yet. Tap Edit to add your first item.")
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilitySummary)
    }

    private var accessibilitySummary: String {
        if graph.nodes.isEmpty { return "Map with nothing drawn yet." }
        var lookup: [UUID: String] = [:]
        for node in graph.nodes { lookup[node.id] = node.label.isEmpty ? "an item" : node.label }
        let links = graph.edges.compactMap { edge -> String? in
            guard let from = lookup[edge.fromID], let to = lookup[edge.toID] else { return nil }
            switch edge.polarity {
            case .same: return "\(from) leads to \(to), more leads to more"
            case .opposite: return "\(from) leads to \(to), more leads to less"
            case .none: return "\(from) leads to \(to)"
            }
        }
        return "Map of \(graph.nodes.count) items. " + links.joined(separator: ". ")
    }
}

// MARK: - Free map: editing

/// The free canvas. Drag the background to pan, pinch to zoom (the buttons
/// do the same), and use the switch at the bottom to choose what dragging an
/// item does: Move shifts it, Link draws a line from it to another. The two
/// are never live together, so a drag never has to guess which one you meant.
/// Every change can be undone and redone.
struct FeedbackLoopDiagramEditorView: View {
    enum Mode { case move, link }

    struct PendingLink {
        var from: UUID
        var point: CGPoint
    }

    @Bindable var diagram: FeedbackLoopDiagram
    @State private var graph = DiagramGraph()
    @State private var history: [DiagramGraph] = []
    @State private var future: [DiagramGraph] = []
    @State private var pan: CGSize = .zero
    @State private var zoom: CGFloat = 1
    @State private var canvasSize: CGSize = .zero
    @State private var mode: Mode = .move
    @State private var pending: PendingLink?
    @State private var dragBase: DiagramGraph?
    @State private var dragOrigin: CGPoint?
    @State private var panStart: CGSize?
    @State private var zoomBase: CGFloat?
    @State private var zoomBasePan: CGSize?
    @State private var editingNodeID: UUID?
    @State private var sheetBase: DiagramGraph?

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color.clear
                    .contentShape(Rectangle())
                    .gesture(panGesture)

                MapLayer(graph: graph, pan: pan, zoom: zoom)

                ForEach(graph.nodes) { node in
                    nodeView(node)
                        .position(MapGeometry.screen(node, pan: pan, zoom: zoom))
                }

                if let link = pending,
                   let from = graph.nodes.first(where: { $0.id == link.from }) {
                    Canvas { context, _ in
                        var path = Path()
                        path.move(to: MapGeometry.screen(from, pan: pan, zoom: zoom))
                        path.addLine(to: link.point)
                        context.stroke(path, with: .color(Anchor.Theme.accent),
                                       style: StrokeStyle(lineWidth: 2, dash: [6, 4]))
                    }
                    .allowsHitTesting(false)
                }

                if graph.nodes.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "point.3.connected.trianglepath.dotted")
                            .font(.largeTitle)
                            .foregroundStyle(.tertiary)
                        Text("Tap the plus to add your first item")
                            .foregroundStyle(.secondary)
                    }
                    .allowsHitTesting(false)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .coordinateSpace(name: "map")
            .gesture(zoomGesture)
            .clipped()
            .onAppear {
                canvasSize = geo.size
                load(size: geo.size)
            }
            .onChange(of: geo.size) { _, newSize in
                canvasSize = newSize
            }
        }
        .anchorBackground()
        .toolbar {
            ToolbarItem(placement: .principal) {
                TextField("Title", text: $diagram.title)
                    .multilineTextAlignment(.center)
            }
        }
        .safeAreaInset(edge: .bottom) { controls }
        .onChange(of: graph) { _, newValue in
            save(newValue)
        }
        .sheet(isPresented: Binding(get: { editingNodeID != nil }, set: { if !$0 { editingNodeID = nil } }),
               onDismiss: {
                   if let base = sheetBase, base != graph { commit(base) }
                   sheetBase = nil
               }) {
            if let id = editingNodeID {
                MapItemSheet(graph: $graph, nodeID: id)
            }
        }
    }

    // MARK: Controls

    private var controls: some View {
        VStack(spacing: 10) {
            if mode == .link {
                Text("Drag from one item onto another to link them.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Picker("What dragging an item does", selection: $mode) {
                Text("Move").tag(Mode.move)
                Text("Link").tag(Mode.link)
            }
            .pickerStyle(.segmented)

            HStack {
                toolButton("plus.circle", "Add an item") { addNode() }
                toolButton("arrow.uturn.backward", "Undo", disabled: history.isEmpty) { undo() }
                toolButton("arrow.uturn.forward", "Redo", disabled: future.isEmpty) { redo() }
                toolButton("minus.magnifyingglass", "Zoom out") { stepZoom(1 / 1.25) }
                toolButton("plus.magnifyingglass", "Zoom in") { stepZoom(1.25) }
                toolButton("arrow.up.left.and.arrow.down.right", "Fit everything") { fitAll() }
            }
        }
        .padding()
        .background(.thinMaterial)
    }

    private func toolButton(_ icon: String, _ label: String, disabled: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.title3)
                .frame(maxWidth: .infinity, minHeight: 36)
        }
        .disabled(disabled)
        .accessibilityLabel(label)
    }

    // MARK: Items

    @ViewBuilder
    private func nodeView(_ node: DiagramNode) -> some View {
        let label = MapNodeLabel(node: node, highlighted: pending?.from == node.id)
        if mode == .link {
            label
                .scaleEffect(zoom)
                .gesture(linkGesture(for: node))
        } else {
            // Editing lives on a small dedicated button rather than a tap on
            // the item itself, so a tap and a drag never compete.
            label
                .overlay(alignment: .topTrailing) {
                    Button {
                        openSheet(for: node.id)
                    } label: {
                        Image(systemName: "pencil.circle.fill")
                            .font(.title3)
                            .foregroundStyle(Anchor.Theme.accent)
                            .background(Circle().fill(.white))
                    }
                    .buttonStyle(.plain)
                    .offset(x: 10, y: -10)
                    .accessibilityLabel("Edit \(node.label.isEmpty ? "item" : node.label)")
                }
                .scaleEffect(zoom)
                .gesture(moveGesture(for: node))
        }
    }

    private func moveGesture(for node: DiagramNode) -> some Gesture {
        DragGesture(minimumDistance: 3, coordinateSpace: .named("map"))
            .onChanged { value in
                if dragBase == nil {
                    dragBase = graph
                    dragOrigin = CGPoint(x: node.x, y: node.y)
                }
                guard let origin = dragOrigin,
                      let index = graph.nodes.firstIndex(where: { $0.id == node.id }) else { return }
                graph.nodes[index].x = Double(origin.x + value.translation.width / zoom)
                graph.nodes[index].y = Double(origin.y + value.translation.height / zoom)
            }
            .onEnded { _ in
                if let base = dragBase, base != graph { commit(base) }
                dragBase = nil
                dragOrigin = nil
            }
    }

    private func linkGesture(for node: DiagramNode) -> some Gesture {
        DragGesture(minimumDistance: 4, coordinateSpace: .named("map"))
            .onChanged { value in
                pending = PendingLink(from: node.id, point: value.location)
            }
            .onEnded { value in
                pending = nil
                if let target = item(at: value.location, excluding: node.id) {
                    addLink(from: node.id, to: target.id)
                }
            }
    }

    private func item(at point: CGPoint, excluding id: UUID) -> DiagramNode? {
        graph.nodes.first { other in
            guard other.id != id else { return false }
            let centre = MapGeometry.screen(other, pan: pan, zoom: zoom)
            return abs(centre.x - point.x) <= MapGeometry.halfWidth * zoom
                && abs(centre.y - point.y) <= MapGeometry.halfHeight * zoom
        }
    }

    private func addLink(from: UUID, to: UUID) {
        guard !graph.edges.contains(where: { $0.fromID == from && $0.toID == to }) else { return }
        let before = graph
        graph.edges.append(DiagramEdge(fromID: from, toID: to, polarity: .none))
        commit(before)
    }

    private func addNode() {
        let before = graph
        let z = max(zoom, 0.01)
        let centreX = (canvasSize.width / 2 - pan.width) / z
        let centreY = (canvasSize.height / 2 - pan.height) / z
        let stagger = Double(graph.nodes.count % 5) * 24
        let node = DiagramNode(label: "", x: Double(centreX) + stagger - 48, y: Double(centreY) + stagger - 48)
        graph.nodes.append(node)
        commit(before)
        openSheet(for: node.id)
    }

    private func openSheet(for id: UUID) {
        sheetBase = graph
        editingNodeID = id
    }

    // MARK: Pan and zoom

    private var panGesture: some Gesture {
        DragGesture(minimumDistance: 4)
            .onChanged { value in
                if panStart == nil { panStart = pan }
                let start = panStart ?? pan
                pan = CGSize(width: start.width + value.translation.width,
                             height: start.height + value.translation.height)
            }
            .onEnded { _ in panStart = nil }
    }

    private var zoomGesture: some Gesture {
        MagnifyGesture()
            .onChanged { value in
                if zoomBase == nil {
                    zoomBase = zoom
                    zoomBasePan = pan
                }
                applyZoom((zoomBase ?? zoom) * value.magnification,
                          baseZoom: zoomBase ?? zoom,
                          basePan: zoomBasePan ?? pan)
            }
            .onEnded { _ in
                zoomBase = nil
                zoomBasePan = nil
            }
    }

    /// Zooms about the middle of the canvas, so what you are looking at stays
    /// where it is.
    private func applyZoom(_ target: CGFloat, baseZoom: CGFloat, basePan: CGSize) {
        let z = min(max(target, MapGeometry.minZoom), MapGeometry.maxZoom)
        let ratio = z / max(baseZoom, 0.01)
        let cx = canvasSize.width / 2
        let cy = canvasSize.height / 2
        zoom = z
        pan = CGSize(width: cx - (cx - basePan.width) * ratio,
                     height: cy - (cy - basePan.height) * ratio)
    }

    private func stepZoom(_ factor: CGFloat) {
        applyZoom(zoom * factor, baseZoom: zoom, basePan: pan)
    }

    private func fitAll() {
        let fit = MapGeometry.fit(graph, in: canvasSize, maxFitZoom: 1.3)
        withAnimation {
            pan = fit.pan
            zoom = fit.zoom
        }
    }

    // MARK: History and saving

    private func commit(_ before: DiagramGraph) {
        history.append(before)
        if history.count > 60 { history.removeFirst() }
        future = []
    }

    private func undo() {
        guard let previous = history.popLast() else { return }
        future.append(graph)
        graph = previous
    }

    private func redo() {
        guard let next = future.popLast() else { return }
        history.append(graph)
        graph = next
    }

    private func load(size: CGSize) {
        let loaded = DiagramGraph.decoded(from: diagram.graphJSON)
        graph = loaded
        let fit = MapGeometry.fit(loaded, in: size, maxFitZoom: 1.2)
        pan = fit.pan
        zoom = fit.zoom
    }

    /// Writes the map back only when something changed, so opening the
    /// editor does not move the diagram up the list or rewrite an old one.
    private func save(_ new: DiagramGraph) {
        if new != DiagramGraph.decoded(from: diagram.graphJSON) {
            var toSave = new
            toSave.version = 2
            diagram.graphJSON = toSave.encoded()
            diagram.lastEditedAt = .now
        }
    }
}

/// One item on a map, in one sheet: its words, its colour, and the links
/// that leave it, each with an optional sign and a few words of its own.
struct MapItemSheet: View {
    @Binding var graph: DiagramGraph
    let nodeID: UUID

    private var outgoing: [DiagramEdge] {
        graph.edges.filter { $0.fromID == nodeID }
    }

    private var linkTargets: [DiagramNode] {
        graph.nodes.filter { other in
            other.id != nodeID && !graph.edges.contains(where: { $0.fromID == nodeID && $0.toID == other.id })
        }
    }

    var body: some View {
        Anchor.ItemEditorSheet(
            title: "Edit item",
            onDelete: deleteItem,
            deleteTitle: "Delete item",
            deleteQuestion: "Delete this item and its links?"
        ) {
            Form {
                if graph.nodes.contains(where: { $0.id == nodeID }) {
                    Section("What is it") {
                        TextField("Write it in your own words", text: labelBinding, axis: .vertical)
                    }

                    Section("Colour") {
                        colourRow
                    }

                    Section {
                        ForEach(outgoing) { edge in
                            linkRow(edge)
                        }
                        Menu {
                            ForEach(linkTargets) { other in
                                Button(other.label.isEmpty ? "Item" : other.label) {
                                    graph.edges.append(DiagramEdge(fromID: nodeID, toID: other.id, polarity: .none))
                                }
                            }
                        } label: {
                            Label("Add a link to another item", systemImage: "arrow.right")
                        }
                        .disabled(linkTargets.isEmpty)
                    } header: {
                        Text("Links from this item")
                    } footer: {
                        Text("A sign is optional. More leads to more shows a plus on the arrow, more leads to less shows a minus.")
                    }
                }
            }
        }
    }

    private var colourRow: some View {
        let current = graph.nodes.first(where: { $0.id == nodeID })?.colour ?? .sage
        return HStack(spacing: 14) {
            ForEach(NodeColour.allCases) { option in
                Button {
                    if let index = graph.nodes.firstIndex(where: { $0.id == nodeID }) {
                        graph.nodes[index].colour = option == .sage ? nil : option
                    }
                } label: {
                    Circle()
                        .fill(option.fill)
                        .frame(width: 32, height: 32)
                        .overlay(Circle().stroke(Color.secondary.opacity(0.5), lineWidth: 1))
                        .overlay {
                            if option == current {
                                Image(systemName: "checkmark")
                                    .font(.footnote.weight(.bold))
                                    .foregroundStyle(.primary)
                            }
                        }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(option.name)
                .accessibilityAddTraits(option == current ? .isSelected : [])
            }
        }
    }

    private func linkRow(_ edge: DiagramEdge) -> some View {
        let target = graph.nodes.first(where: { $0.id == edge.toID })
        let name = (target?.label ?? "").isEmpty ? "another item" : (target?.label ?? "")
        return VStack(alignment: .leading, spacing: 8) {
            Text("To \(name)")
                .font(.subheadline.weight(.medium))
            Picker("Sign", selection: polarityBinding(edge.id)) {
                Text("No sign").tag(EdgePolarity.none)
                Text("More leads to more").tag(EdgePolarity.same)
                Text("More leads to less").tag(EdgePolarity.opposite)
            }
            .pickerStyle(.menu)
            TextField("How, in your words (optional)", text: wordsBinding(edge.id))
                .font(.footnote)
        }
        .padding(.vertical, 2)
        .anchorDeletable("Remove link") {
            graph.edges.removeAll { $0.id == edge.id }
        }
    }

    private var labelBinding: Binding<String> {
        Binding(
            get: { graph.nodes.first(where: { $0.id == nodeID })?.label ?? "" },
            set: { value in
                if let index = graph.nodes.firstIndex(where: { $0.id == nodeID }) {
                    graph.nodes[index].label = value
                }
            }
        )
    }

    private func polarityBinding(_ edgeID: UUID) -> Binding<EdgePolarity> {
        Binding(
            get: { graph.edges.first(where: { $0.id == edgeID })?.polarity ?? .none },
            set: { value in
                if let index = graph.edges.firstIndex(where: { $0.id == edgeID }) {
                    graph.edges[index].polarity = value
                }
            }
        )
    }

    private func wordsBinding(_ edgeID: UUID) -> Binding<String> {
        Binding(
            get: { graph.edges.first(where: { $0.id == edgeID })?.label ?? "" },
            set: { value in
                if let index = graph.edges.firstIndex(where: { $0.id == edgeID }) {
                    graph.edges[index].label = value
                }
            }
        )
    }

    private func deleteItem() {
        graph.nodes.removeAll { $0.id == nodeID }
        graph.edges.removeAll { $0.fromID == nodeID || $0.toID == nodeID }
    }
}


// MARK: - Templates

/// A starting point the person can copy and then rewrite. Each one is built
/// fresh in code, so a copy never shares ids or storage with another.
struct DiagramTemplate: Identifiable {
    let id: String
    let name: String
    let summary: String
    let build: () -> DiagramGraph

    /// One plain line about what kind of diagram it makes.
    var kindLine: String {
        let graph = build()
        switch graph.kind {
        case .loop:
            if let character = graph.loopCharacter { return "Loop, \(character.name.lowercased())" }
            return "Loop"
        case .map:
            return "Map, \(graph.nodes.count) items"
        }
    }
}

enum DiagramTemplates {
    static let all: [DiagramTemplate] = [
        DiagramTemplate(
            id: "putting-off",
            name: "Putting something off",
            summary: "Each time round, the thing feels bigger.",
            build: {
                DiagramGraph.loop([
                    ("I put it off", .same),
                    ("It feels bigger", .same),
                    ("I worry about it more", .same)
                ])
            }
        ),
        DiagramTemplate(
            id: "sleep-and-energy",
            name: "Poor sleep and low energy",
            summary: "A rough night leads to a rough day, which leads to another rough night.",
            build: {
                DiagramGraph.loop([
                    ("I sleep badly", .same),
                    ("I have less energy", .same),
                    ("I do less of what looks after me", .same)
                ])
            }
        ),
        DiagramTemplate(
            id: "stretched-then-break",
            name: "Stretched, then a break",
            summary: "Feeling stretched leads to a break, and the break eases it.",
            build: {
                DiagramGraph.loop([
                    ("Feeling stretched", .same),
                    ("I take a break", .same),
                    ("I feel more rested", .opposite)
                ])
            }
        ),
        DiagramTemplate(
            id: "around-me",
            name: "What is around me",
            summary: "A map with you in the middle. Rename, move and add whatever fits.",
            build: {
                var graph = DiagramGraph(kind: .map)
                let middle = DiagramNode(label: "Me", x: 300, y: 200, colour: .amber)
                let others = [
                    DiagramNode(label: "Home", x: 300, y: 50),
                    DiagramNode(label: "Work or school", x: 520, y: 200),
                    DiagramNode(label: "People I trust", x: 300, y: 350),
                    DiagramNode(label: "My body", x: 80, y: 200)
                ]
                graph.nodes = [middle] + others
                for other in others {
                    graph.edges.append(DiagramEdge(fromID: other.id, toID: middle.id, polarity: .none))
                }
                return graph
            }
        )
    ]
}

struct DiagramTemplatePickerView: View {
    var onPick: (DiagramTemplate) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    ForEach(DiagramTemplates.all) { template in
                        Button { onPick(template) } label: {
                            Anchor.Card(accentColor: Anchor.Theme.sage) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(template.name)
                                        .font(.system(.headline, design: .rounded))
                                        .foregroundStyle(.primary)
                                    Text(template.summary)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                        .multilineTextAlignment(.leading)
                                    Text(template.kindLine)
                                        .font(.footnote)
                                        .foregroundStyle(.tertiary)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .contentShape(Rectangle())
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityHint("Makes a copy you can change")
                    }
                }
                .padding()
            }
            .anchorBackground()
            .navigationTitle("Start from a template")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Sharing a diagram

/// One line of the written reading: how a step leads to the next, and the
/// person's own words on that link if they wrote any.
struct DiagramReadingLine {
    let sentence: String
    let words: String?
}

extension DiagramGraph {
    /// The links in plain words, in loop order for a loop. A loop that is
    /// not closed yet has nothing to read out.
    var readingLines: [DiagramReadingLine] {
        if kind == .loop && !isClosedLoop { return [] }
        let fallback = kind == .loop ? "A step" : "An item"
        let names = Dictionary(nodes.map { ($0.id, $0.label.isEmpty ? fallback : $0.label) },
                               uniquingKeysWith: { first, _ in first })
        let ordered: [DiagramEdge] = kind == .loop ? nodes.compactMap { edge(from: $0.id) } : edges
        return ordered.compactMap { edge in
            guard let from = names[edge.fromID], let to = names[edge.toID] else { return nil }
            let sign: String
            switch edge.polarity {
            case .same: sign = " More leads to more."
            case .opposite: sign = " More leads to less."
            case .none: sign = ""
            }
            return DiagramReadingLine(sentence: "\(from) leads to \(to).\(sign)",
                                      words: edge.label.isEmpty ? nil : edge.label)
        }
    }
}

/// The page that becomes the picture and the PDF. It is always drawn light on
/// white with a fixed text size, so what is shared looks the same whatever the
/// phone is set to, and it is easy to print.
struct DiagramSharePage: View {
    let title: String
    let graph: DiagramGraph
    let includeReading: Bool

    static let width: CGFloat = 612
    private static let inset: CGFloat = 40

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title.isEmpty ? "Untitled" : title)
                .font(.system(size: 24, weight: .bold, design: .rounded))
            Text(Date.now.formatted(date: .long, time: .omitted))
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
            diagram
            if includeReading && (!graph.readingLines.isEmpty || graph.loopCharacter != nil) {
                reading
            }
        }
        .fixedSize(horizontal: false, vertical: true)
        .padding(Self.inset)
        .frame(width: Self.width, alignment: .topLeading)
        .background(Color.white)
        .foregroundStyle(Color.black)
        .environment(\.colorScheme, .light)
        .environment(\.dynamicTypeSize, .large)
    }

    @ViewBuilder
    private var diagram: some View {
        let side = Self.width - Self.inset * 2
        if graph.kind == .loop {
            LoopRingView(graph: graph)
                .frame(width: side, height: 420)
        } else {
            MapReadView(graph: graph)
                .frame(width: side, height: 400)
        }
    }

    private var reading: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let character = graph.loopCharacter {
                Text(character.name)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                Text(character.sentence)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            ForEach(Array(graph.readingLines.enumerated()), id: \.offset) { _, line in
                VStack(alignment: .leading, spacing: 1) {
                    Text(line.sentence)
                        .font(.system(size: 12))
                    if let words = line.words {
                        Text(words)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// The two files made from a page, and the folder they sit in.
struct DiagramShareFiles {
    let preview: UIImage
    let pngURL: URL
    let pdfURL: URL
    let folder: URL
}

/// Shows the page and hands it to the system share sheet as a picture or a
/// PDF. Everything is made on the device and kept in a temporary folder that
/// is removed when this closes; nothing is uploaded.
struct DiagramShareView: View {
    let title: String
    let graph: DiagramGraph

    @Environment(\.dismiss) private var dismiss
    @State private var includeReading = true
    @State private var files: DiagramShareFiles?
    @State private var failed = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    if let files {
                        Image(uiImage: files.preview)
                            .resizable()
                            .scaledToFit()
                            .background(Color.white)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.3)))
                            .accessibilityLabel("Preview of the page you will share")
                    } else if failed {
                        Text("The page could not be made. Close this and try again.")
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    } else {
                        ProgressView()
                            .padding(.vertical, 40)
                    }

                    Toggle("Include the written reading", isOn: $includeReading)

                    if let files {
                        ShareLink(item: files.pngURL) {
                            Label("Share as picture", systemImage: "photo")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        ShareLink(item: files.pdfURL) {
                            Label("Share as PDF", systemImage: "doc.richtext")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                    }
                }
                .padding()
            }
            .anchorBackground()
            .navigationTitle("Share diagram")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .task(id: includeReading) { prepare() }
            .onDisappear { removeFiles() }
        }
    }

    private func removeFiles() {
        if let folder = files?.folder {
            try? FileManager.default.removeItem(at: folder)
        }
        files = nil
    }

    private func prepare() {
        removeFiles()
        failed = false
        let renderer = ImageRenderer(content: DiagramSharePage(title: title, graph: graph, includeReading: includeReading))
        renderer.scale = 3
        guard let image = renderer.uiImage, let png = image.pngData() else {
            failed = true
            return
        }

        let manager = FileManager.default
        let folder = manager.temporaryDirectory.appendingPathComponent("diagram-share-\(UUID().uuidString)", isDirectory: true)
        let base = Self.fileName(for: title)
        let pngURL = folder.appendingPathComponent("\(base).png")
        let pdfURL = folder.appendingPathComponent("\(base).pdf")

        do {
            try manager.createDirectory(at: folder, withIntermediateDirectories: true,
                                        attributes: [.protectionKey: FileProtectionType.complete])
            try png.write(to: pngURL, options: .completeFileProtection)

            var wrotePDF = false
            renderer.render { size, draw in
                var box = CGRect(origin: .zero, size: size)
                guard let pdf = CGContext(pdfURL as CFURL, mediaBox: &box, nil) else { return }
                pdf.beginPDFPage(nil)
                draw(pdf)
                pdf.endPDFPage()
                pdf.closePDF()
                wrotePDF = true
            }
            guard wrotePDF else {
                try? manager.removeItem(at: folder)
                failed = true
                return
            }
            try? manager.setAttributes([.protectionKey: FileProtectionType.complete], ofItemAtPath: pdfURL.path)
            files = DiagramShareFiles(preview: image, pngURL: pngURL, pdfURL: pdfURL, folder: folder)
        } catch {
            try? manager.removeItem(at: folder)
            failed = true
        }
    }

    /// The diagram's own title as the file name, with anything a file name
    /// cannot hold taken out.
    private static func fileName(for title: String) -> String {
        let bad = CharacterSet(charactersIn: "/\\:?%*|\"<>")
        let cleaned = title.components(separatedBy: bad).joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.isEmpty ? "Diagram" : String(cleaned.prefix(60))
    }
}
