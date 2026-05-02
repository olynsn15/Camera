//
//  OverlayGridView.swift
//  Camera
//
//  Created by Carolyn Santana on 02/05/26.
//


import SwiftUI

struct OverlayGridView: View {
    let overlay: GridOverlay
    let aspectRatio: AspectRatio

    var body: some View {
        switch overlay {
        case .none:
            EmptyView()
        case .ruleOfThird:
            RuleOfThirdGrid()
        case .symmetry:
            SymmetryGrid()
        }
    }
}

// MARK: - Rule of Thirds

struct RuleOfThirdGrid: View {
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let thirdW = w / 3
            let thirdH = h / 3

            ZStack {
                // Vertical lines
                Path { path in
                    path.move(to: CGPoint(x: thirdW, y: 0))
                    path.addLine(to: CGPoint(x: thirdW, y: h))
                    path.move(to: CGPoint(x: thirdW * 2, y: 0))
                    path.addLine(to: CGPoint(x: thirdW * 2, y: h))
                }
                .stroke(Color.white.opacity(0.5), lineWidth: 0.7)

                // Horizontal lines
                Path { path in
                    path.move(to: CGPoint(x: 0, y: thirdH))
                    path.addLine(to: CGPoint(x: w, y: thirdH))
                    path.move(to: CGPoint(x: 0, y: thirdH * 2))
                    path.addLine(to: CGPoint(x: w, y: thirdH * 2))
                }
                .stroke(Color.white.opacity(0.5), lineWidth: 0.7)

                // Intersection dots (4 power points)
                ForEach([1, 2], id: \.self) { col in
                    ForEach([1, 2], id: \.self) { row in
                        Circle()
                            .fill(Color.green)
                            .frame(width: 8, height: 8)
                            .position(
                                x: thirdW * CGFloat(col),
                                y: thirdH * CGFloat(row)
                            )
                    }
                }
            }
        }
    }
}

// MARK: - Symmetry Grid

struct SymmetryGrid: View {
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height

            ZStack {
                // Center vertical
                Path { path in
                    path.move(to: CGPoint(x: w / 2, y: 0))
                    path.addLine(to: CGPoint(x: w / 2, y: h))
                }
                .stroke(Color.white.opacity(0.7), lineWidth: 0.8)

                // Center horizontal
                Path { path in
                    path.move(to: CGPoint(x: 0, y: h / 2))
                    path.addLine(to: CGPoint(x: w, y: h / 2))
                }
                .stroke(Color.white.opacity(0.7), lineWidth: 0.8)

                // Quarter verticals
                Path { path in
                    path.move(to: CGPoint(x: w / 4, y: 0))
                    path.addLine(to: CGPoint(x: w / 4, y: h))
                    path.move(to: CGPoint(x: w * 3 / 4, y: 0))
                    path.addLine(to: CGPoint(x: w * 3 / 4, y: h))
                }
                .stroke(Color.white.opacity(0.3), lineWidth: 0.5)

                // Quarter horizontals
                Path { path in
                    path.move(to: CGPoint(x: 0, y: h / 4))
                    path.addLine(to: CGPoint(x: w, y: h / 4))
                    path.move(to: CGPoint(x: 0, y: h * 3 / 4))
                    path.addLine(to: CGPoint(x: w, y: h * 3 / 4))
                }
                .stroke(Color.white.opacity(0.3), lineWidth: 0.5)

                // Diagonal lines for symmetry reference
                Path { path in
                    path.move(to: CGPoint(x: 0, y: 0))
                    path.addLine(to: CGPoint(x: w, y: h))
                    path.move(to: CGPoint(x: w, y: 0))
                    path.addLine(to: CGPoint(x: 0, y: h))
                }
                .stroke(Color.white.opacity(0.2), lineWidth: 0.5)

                // Center cross dot
                Circle()
                    .fill(Color.white.opacity(0.8))
                    .frame(width: 6, height: 6)
                    .position(x: w / 2, y: h / 2)
            }
        }
    }
}