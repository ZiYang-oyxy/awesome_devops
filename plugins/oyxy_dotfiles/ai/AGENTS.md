# Agent Instructions

## Summary Guidelines

- All summaries must be written in **Chinese (中文)**.

## Diagram Guidelines

- When writing documentation, use **Mermaid** for flowcharts, architecture diagrams, and any visual that clarifies the content. **Prefer diagrams and lists** over long prose.
- **Layout**: Aim for a **balanced, roughly square** aspect ratio. Avoid diagrams that are excessively tall/narrow or excessively wide/flat. Only switch to a horizontal (`LR`) layout as a last resort when a balanced layout is not achievable.
- **Color**: Use colors (via `style`, `classDef`, or `:::className`) to visually distinguish node categories, highlight critical paths, or group related elements. Keep the palette harmonious — 3–5 colors is usually sufficient.
- **Subgraphs**: Group related nodes into `subgraph` blocks with meaningful titles to create visual regions.
- **Node shapes**: Use shapes semantically — rounded rectangles for steps, diamonds for decisions, cylinders for databases, hexagons for events. Do not mix shapes randomly.
- **Link styles**: Highlight critical paths with thick arrows (`==>`) or `linkStyle`. Add concise labels on edges to describe transitions.
- **Node text**: Keep node labels short (≤ 5 words). Move details to annotations or surrounding prose.
- **Color palette reference** (use as a starting point, adapt as needed):
  ```
  classDef primary fill:#6C9BD2,stroke:#5B8AC1,color:#fff
  classDef success fill:#7EC699,stroke:#6DB588,color:#fff
  classDef warning fill:#F0C27A,stroke:#DFB169,color:#fff
  classDef danger  fill:#E8918C,stroke:#D7807B,color:#fff
  classDef grey    fill:#B0B5BD,stroke:#9FA4AC,color:#fff
  ```
- When generating, modifying, or debugging Mermaid diagrams, you **must** first use the `mermaid-sop-check` skill and complete its SOP render validation before delivering.
