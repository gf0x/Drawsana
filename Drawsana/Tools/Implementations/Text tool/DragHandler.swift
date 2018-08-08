//
//  DragHandler.swift
//  Drawsana
//
//  Created by Steve Landey on 8/8/18.
//  Copyright © 2018 Asana. All rights reserved.
//

import CoreGraphics

class DragHandler {
  let shape: TextShape
  weak var textTool: TextTool?
  var startPoint: CGPoint = .zero

  init(
    shape: TextShape,
    textTool: TextTool)
  {
    self.shape = shape
    self.textTool = textTool
  }

  func handleDragStart(context: ToolOperationContext, point: CGPoint) {
    startPoint = point
  }

  func handleDragContinue(context: ToolOperationContext, point: CGPoint, velocity: CGPoint) {

  }

  func handleDragEnd(context: ToolOperationContext, point: CGPoint) {

  }

  func handleDragCancel(context: ToolOperationContext, point: CGPoint) {

  }
}

/// User is dragging the text itself to a new location
class MoveHandler: DragHandler {
  private var originalTransform: ShapeTransform

  override init(
    shape: TextShape,
    textTool: TextTool)
  {
    self.originalTransform = shape.transform
    super.init(shape: shape, textTool: textTool)
  }

  override func handleDragContinue(context: ToolOperationContext, point: CGPoint, velocity: CGPoint) {
    let delta = point - startPoint
    shape.transform = originalTransform.translated(by: delta)
    textTool?.updateTextView()
  }

  override func handleDragEnd(context: ToolOperationContext, point: CGPoint) {
    let delta = CGPoint(x: point.x - startPoint.x, y: point.y - startPoint.y)
    context.operationStack.apply(operation: ChangeTransformOperation(
      shape: shape,
      transform: originalTransform.translated(by: delta),
      originalTransform: originalTransform))
  }

  override func handleDragCancel(context: ToolOperationContext, point: CGPoint) {
    shape.transform = originalTransform
    context.toolSettings.isPersistentBufferDirty = true
    textTool?.updateShapeFrame()
  }
}

/// User is dragging the lower-right handle to change the size and rotation
/// of the text box
class ResizeAndRotateHandler: DragHandler {
  private var originalTransform: ShapeTransform

  override init(
    shape: TextShape,
    textTool: TextTool)
  {
    self.originalTransform = shape.transform
    super.init(shape: shape, textTool: textTool)
  }

  private func getResizeAndRotateTransform(point: CGPoint) -> ShapeTransform {
    let originalDelta = CGPoint(x: startPoint.x - shape.transform.translation.x, y: startPoint.y - shape.transform.translation.y)
    let newDelta = CGPoint(x: point.x - shape.transform.translation.x, y: point.y - shape.transform.translation.y)
    let originalDistance = originalDelta.length
    let newDistance = newDelta.length
    let originalAngle = atan2(originalDelta.y, originalDelta.x)
    let newAngle = atan2(newDelta.y, newDelta.x)
    let scaleChange = newDistance / originalDistance
    let angleChange = newAngle - originalAngle
    return originalTransform.scaled(by: scaleChange).rotated(by: angleChange)
  }

  override func handleDragContinue(context: ToolOperationContext, point: CGPoint, velocity: CGPoint) {
    shape.transform = getResizeAndRotateTransform(point: point)
    textTool?.updateTextView()
  }

  override func handleDragEnd(context: ToolOperationContext, point: CGPoint) {
    context.operationStack.apply(operation: ChangeTransformOperation(
      shape: shape,
      transform: getResizeAndRotateTransform(point: point),
      originalTransform: originalTransform))
  }

  override func handleDragCancel(context: ToolOperationContext, point: CGPoint) {
    shape.transform = originalTransform
    context.toolSettings.isPersistentBufferDirty = true
    textTool?.updateShapeFrame()
  }
}

/// User is dragging the middle-right handle to change the width of the text
/// box
class ChangeWidthHandler: DragHandler {
  private var originalWidth: CGFloat?
  private var originalBoundingRect: CGRect = .zero

  override init(
    shape: TextShape,
    textTool: TextTool)
  {
    self.originalWidth = shape.explicitWidth
    self.originalBoundingRect = shape.boundingRect
    super.init(shape: shape, textTool: textTool)
    shape.explicitWidth = shape.explicitWidth ?? shape.boundingRect.size.width
  }

  override func handleDragContinue(context: ToolOperationContext, point: CGPoint, velocity: CGPoint) {
    originalWidth = shape.explicitWidth
    originalBoundingRect = shape.boundingRect
    shape.explicitWidth = shape.explicitWidth ?? shape.boundingRect.size.width
  }

  override func handleDragEnd(context: ToolOperationContext, point: CGPoint) {
    guard let textTool = textTool else { return }
    let translatedBoundingRect = shape.boundingRect.applying(
      CGAffineTransform(translationX: shape.transform.translation.x,
                        y: shape.transform.translation.y))
    let distanceFromShapeCenter = (point - translatedBoundingRect.middle).length
    let desiredWidthInScreenCoordinates = (distanceFromShapeCenter - textTool.editingView.changeWidthControlView.frame.size.width / 2) * 2
    shape.explicitWidth = desiredWidthInScreenCoordinates / shape.transform.scale
    textTool.updateShapeFrame()
  }

  override func handleDragCancel(context: ToolOperationContext, point: CGPoint) {
    shape.explicitWidth = originalWidth
    shape.boundingRect = originalBoundingRect
    context.toolSettings.isPersistentBufferDirty = true
    textTool?.updateTextView()
  }
}