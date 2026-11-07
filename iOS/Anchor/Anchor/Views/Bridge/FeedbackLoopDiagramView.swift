//
//  FeedbackLoopDiagramView.swift
//  Anchor
//
//  Deliberately simple: drag to place nodes, tap two nodes in sequence to
//  connect them, tap a node to rename it. This is a tool for the user's
//  own systems metaphors (e.g. "my defenses work like Cloudflare") to
//  become something they can literally show a clinician — not a general
//  diagramming app, so it stays minimal on purpose.
//

import SwiftUI
import SwiftData

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
}

struct DiagramGraph: Codable, Equatable {
    var nodes: [DiagramNode] = []
    var edges: [DiagramEdge] = []
}

struct FeedbackLoopDiagramListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var diagrams: [FeedbackLoopDiagram]
    @State private var showingEditor = false

    var body: some View {
        ScrollView {
            VStack(spacing: Anchor.Theme.spacing) {
                if diagrams.isEmpty {
                    Anchor.EmptyState(
                        icon: "point.3.connected.trianglepath.dotted",
                        title: "No diagrams yet",
                        message: "Draw how things feed into each other, in your own words, to show someone else.",
                        actionTitle: "New diagram",
                        tint: Anchor.Theme.sage
                    ) { addDiagram() }
                } else {
                    ForEach(diagrams) { diagram in
                        NavigationLink {
                            FeedbackLoopDiagramView(diagram: diagram)
                        } label: {
                            Anchor.Card(accentColor: Anchor.Theme.sage) {
                                HStack {
                                    Text(diagram.title.isEmpty ? "Untitled" : diagram.title)
                                        .font(.system(.headline, design: .rounded))
                                        .foregroundStyle(.primary)
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.tertiary)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                    Button {
                        addDiagram()
                    } label: {
                        Label("New diagram", systemImage: "plus")
                    }
                    .buttonStyle(Anchor.SecondaryButtonStyle())
                }
            }
            .padding()
        }
        .anchorBackground()
        .navigationTitle("Feedback-loop diagrams")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                if !diagrams.isEmpty {
                    Anchor.EditToolbarButton { showingEditor = true }
                }
            }
        }
        .sheet(isPresented: $showingEditor) {
            Anchor.EditorSheet(title: "Edit diagrams") {
                FeedbackLoopDiagramsManageView()
            }
        }
    }

    private func addDiagram() {
        let emptyGraph = DiagramGraph()
        let data = (try? JSONEncoder().encode(emptyGraph)) ?? Data()
        modelContext.insert(FeedbackLoopDiagram(title: "New diagram", graphJSON: data))
    }
}

/// Delete diagrams. Presented from Edit; a diagram's own contents are
/// edited from inside the diagram.
private struct FeedbackLoopDiagramsManageView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var diagrams: [FeedbackLoopDiagram]

    var body: some View {
        List {
            ForEach(diagrams) { diagram in
                Text(diagram.title.isEmpty ? "Untitled" : diagram.title)
                    .font(.system(.subheadline, design: .rounded))
            }
            .onDelete { offsets in
                for index in offsets { modelContext.delete(diagrams[index]) }
            }
        }
        .toolbar { EditButton() }
    }
}

/// A diagram as something to look at (and show a clinician): nodes and
/// connections, nothing draggable. Edit opens the canvas editor.
struct FeedbackLoopDiagramView: View {
    @Bindable var diagram: FeedbackLoopDiagram
    @State private var graph = DiagramGraph()
    @State private var showingEditor = false

    var body: some View {
        ZStack {
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
        .anchorBackground()
        .navigationTitle(diagram.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Anchor.EditToolbarButton { showingEditor = true }
            }
        }
        .onAppear(perform: loadGraph)
        .sheet(isPresented: $showingEditor, onDismiss: loadGraph) {
            Anchor.EditorSheet(title: "Edit diagram") {
                FeedbackLoopDiagramEditorView(diagram: diagram)
            }
        }
    }

    private func loadGraph() {
        graph = (try? JSONDecoder().decode(DiagramGraph.self, from: diagram.graphJSON)) ?? DiagramGraph()
    }
}

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
