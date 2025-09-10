import SwiftUI

struct ElevationChart: View {
  var elevations: [Double]
  let width: CGFloat
  let max: Double
  let min: Double
  let delta: Double

  let barWidth: CGFloat
  let barHeight: CGFloat = 20
  let barCount: UInt = 20
  let hstackSpacing: CGFloat = 1

  init(elevations: [Double], width: CGFloat) {
    self.elevations = elevations
    self.width = width
    self.max = elevations.max() ?? 0
    self.min = elevations.min() ?? 0
    self.delta = max - min
    let sumOfSpacing: CGFloat = CGFloat(hstackSpacing) * CGFloat(barCount - 1)
    let spaceForBars = width - sumOfSpacing
    self.barWidth = spaceForBars / Double(barCount)
  }

  var body: some View {
    HStack(alignment: .bottom, spacing: hstackSpacing) {
      ForEach(compress(inputs: elevations, outputCount: barCount), id: \.self) { elevation in
        Rectangle().fill(Color(rgb: 0xccccf0)).frame(
          width: barWidth, height: (elevation - min) / Swift.max(1, delta) * barHeight + 4)
      }
    }
  }
}

// Compresses or stretches input to fit into `outputCount` number of elements by summing and averaging
func compress(inputs: [Double], outputCount: UInt) -> [Double] {
  let stride = max(1, Int(Double(inputs.count) / (Double(outputCount)).rounded(.up)))
  var start = 0
  var output: [Double] = []
  while start < inputs.count {
    let slice = inputs[start..<min(start + stride, inputs.count)]
    start += slice.count
    let sampled = slice.reduce(0.0, +) / Double(slice.count)
    output.append(sampled)
  }
  // This might be off by one
  //  assert(output.count == outputCount)
  return output
}
