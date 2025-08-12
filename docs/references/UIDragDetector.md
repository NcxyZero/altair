# UIDragDetector

Properties
ActivatedCursorIcon
ContentId
Read Parallel
Sets the cursor icon to display when the mouse is activated over the parent of this UIDragDetector. If this property is left blank, the detector will use the default icon.

To change the activated cursor icon, set this property to the asset ID of the image you'd like to use.

BoundingBehavior
Enum.UIDragDetectorBoundingBehavior
Read Parallel
Determines bounding behavior of the dragged UI object when the detector's BoundingUI is set. See Enum.UIDragDetectorBoundingBehavior for details on each setting's behavior.

BoundingUI
GuiBase2d
Read Parallel
When set, the UIDragDetector instance will not allow the bounds of the parent GuiObject to be dragged outside the bounds of the BoundingUI instance.

Note that if a portion of the parent GuiObject is outside the BoundingUI bounds, the initial input position at drag start and its relative position during drag will be used for bounding detection until the entirety of the dragged object is within the bounds, after which the object will be constrained inside the bounds.

CursorIcon
ContentId
Read Parallel
Sets the cursor icon to display when the mouse is hovered over the parent of this UIDragDetector. If this property is left blank, the detector will use the default icon.

To change the cursor icon, set this property to the asset ID of the image you'd like to use.

DragAxis
Vector2
Read Parallel
Vector2 value that defines the axis of movement for the dragged object when DragStyle is set to Enum.UIDragDetectorDragStyle.TranslateLine. The axis is defined in the local space of the UIDragDetector unless ReferenceUIInstance is defined, in which case the axis is defined in that instance's local space.

DragRelativity
Enum.UIDragDetectorDragRelativity
Read Parallel
Only applies if a custom drag function is registered through SetDragStyleFunction() or AddConstraintFunction(). Sets the paradigm which defines the relativity of the registered function's inputs/outputs.

For example, returning a UDim2.fromOffset(1, 0) from a registered function with this property set to Enum.UIDragDetectorDragRelativity.Absolute will move the detector's parent to (1, 0) in the designated DragSpace, while returning the same UDim2 with this property set to Enum.UIDragDetectorDragRelativity.Relative will move the detector's parent by (1, 0) in the designated DragSpace.

DragRotation
number
Read Parallel
The rotation performed by the current drag. This value is defined in degrees relative to the local space of the UIDragDetector unless ReferenceUIInstance is defined, in which case the rotation is defined in the local space of that instance and from its positive X axis.

This property can be changed while there is no active drag to rotate the dragged object.

DragSpace
Enum.UIDragDetectorDragSpace
Read Parallel
Only applies if a custom drag function is registered through SetDragStyleFunction() or AddConstraintFunction(). Sets the paradigm which defines the space of the registered function's inputs/outputs.

For example, if the detector's parent GuiObject is a child of a parent GuiObject that's rotated:

Returning a UDim2.fromOffset(1, 0) from a registered function with this property set to Enum.UIDragDetectorDragSpace.Parent will move the detector's parent GuiObject to the right by 1 pixel in the local space affected by its parent's rotation.

Returning a UDim2.fromOffset(1, 0) from a registered function with this property set to Enum.UIDragDetectorDragSpace.LayerCollector will move the detector's parent GuiObject to the right by 1 pixel in the space of the LayerCollector.

DragStyle
Enum.UIDragDetectorDragStyle
Read Parallel
The paradigm used to generate proposed motion, given a stream of input position vectors. See Enum.UIDragDetectorDragStyle for options.

DragUDim2
UDim2
Read Parallel
The translation performed by the current drag expressed in a UDim2 value. Translation is done through Offset or Scale value changes depending on the DragRelativity value, and it is relative to the detector's local space unless a ReferenceUIInstance is defined.

This property can be changed while there is no active drag to move the dragged object.

Enabled
boolean
Read Parallel
If true, the UIDragDetector responds to user input; if false, it does not.

MaxDragAngle
number
Read Parallel
If this property is greater than MinDragAngle, rotation will be clamped within the range of MinDragAngle and MaxDragAngle. Positive values impede clockwise rotation while negative values impede counterclockwise rotation.

This is not a constraint; it merely impedes the detector's attempts to generate motion in order to remain within limits. See AddConstraintFunction() to add custom constraint to a drag.

Only relevant if DragStyle is Enum.UIDragDetectorDragStyle.Rotate.

MaxDragTranslation
UDim2
Read Parallel
If the corresponding Offset and/or Scale values are greater than those of MinDragTranslation in all dimensions, linear/planar translation will be clamped within the range of MinDragTranslation and MaxDragTranslation.

This is not a constraint; it merely impedes the detector's attempts to generate motion in order to remain within limits. See AddConstraintFunction() to add custom constraint to a drag.

Only relevant if DragStyle is Enum.UIDragDetectorDragStyle.TranslateLine or Enum.UIDragDetectorDragStyle.TranslatePlane.

MinDragAngle
number
Read Parallel
If this property is less than MaxDragAngle, rotation will be clamped within the range of MinDragAngle and MaxDragAngle. Positive values impede clockwise rotation while negative values impede counterclockwise rotation.

This is not a constraint; it merely impedes the detector's attempts to generate motion in order to remain within limits. See AddConstraintFunction() to add custom constraint to a drag.

Only relevant if DragStyle is Enum.UIDragDetectorDragStyle.Rotate.

MinDragTranslation
UDim2
Read Parallel
If the corresponding Offset and/or Scale values are less than those of MaxDragTranslation in all dimensions, linear/planar translation will be clamped within the range of MinDragTranslation and MaxDragTranslation.

This is not a constraint; it merely impedes the detector's attempts to generate motion in order to remain within limits. See AddConstraintFunction() to add custom constraint to a drag.

Only relevant if DragStyle is Enum.UIDragDetectorDragStyle.TranslateLine or Enum.UIDragDetectorDragStyle.TranslatePlane.

ReferenceUIInstance
GuiObject
Read Parallel
A GuiObject instance whose local space and absolute center position is the reference space and origin for the detector. Setting this reference affects properties such as DragUDim2, DragRotation, and the behavior of DragAxis.

ResponseStyle
Enum.UIDragDetectorResponseStyle
Read Parallel
Once the proposed motion has been computed and potentially constrained, this paradigm is used to deterimine how to move (or not move) the GuiObject affected by the UIDragDetector. See Enum.UIDragDetectorResponseStyle for options.

SelectionModeDragSpeed
UDim2
Read Parallel
Defines the maximum drag speed for translation as a combination of Scale and Offset of the first ancestor ScreenGui or SurfaceGui the UIDragDetector belongs to. This value must be positive and any value below 0 will be clamped to 0.

SelectionModeRotateSpeed
number
Read Parallel
Defines the maximum angle per second at which the UIDragDetector can rotate. This value must be positive and any value below 0 will be clamped to 0.

UIDragSpeedAxisMapping
Enum.UIDragSpeedAxisMapping
Read Parallel
Enum.UIDragSpeedAxisMapping value that determines the X/Y dimension dragging speeds.

View all inherited from Instance
View all inherited from Object
Methods
AddConstraintFunction
RBXScriptConnection
Adds a function to modify or constrain proposed motion. The function takes an input UDim2 (position) and float (rotation) of proposed motion and returns a UDim2 and float of modified or unmodified motion. You can add multiple functions which will be called in order by priority, passing the results along in a chain.

The input is expressed in the space defined by the DragSpace property, either as a delta or the final desired position/rotation based on the DragRelativity property. The output should be expressed in the same space and relativity, unless overridden by returning a specified Enum.UIDragDetectorDragRelativity and Enum.UIDragDetectorDragSpace as the third and fourth return values.

To remove an added constraint function, call Disconnect() on the returned connection object.

Parameters
priority: number
The order of priority for functions added via this method. Higher values take precedence over lower values.

function: function
Function for modifying or constraining proposed motion. This function takes in input UDim2 and float of proposed motion and returns a UDim2 and float of modified or unmodified motion. It can optionally return an Enum.UIDragDetectorDragRelativity and Enum.UIDragDetectorDragSpace as the third and fourth return values as output overrides.

Returns
RBXScriptConnection
Use this connection object to remove the constraint function.

GetReferencePosition
UDim2
When no ReferenceUIInstance is set, this function returns the UDim2 position of the dragged object's immediate parent GuiObject (if one exists), or else the UDim2 position of the dragged object.

When a ReferenceUIInstance is set, this function returns the UDim2 position of that reference instance.

Returns
UDim2
UDim2 position of the current drag's reference element.

GetReferenceRotation
number
When no ReferenceUIInstance is set, this function returns the rotation of the dragged object's immediate parent GuiObject (if one exists), or else the rotation of the dragged object.

When a ReferenceUIInstance is set, this function returns the rotation of that reference instance.

Returns
number
Rotation of the current drag's reference element.

SetDragStyleFunction
()
Passes a function to be used if and only if DragStyle is set to Enum.UIDragDetectorDragStyle.Scriptable. The given function receives the signal's screen space input position with type Vector2, and it returns a UDim2 (position) and float (rotation) containing the desired motion of the drag. The space of the return values and the relativity of the motion are determined by the DragSpace and DragRelativity properties, unless overridden by returning a specified Enum.UIDragDetectorDragRelativity and Enum.UIDragDetectorDragSpace as the third and fourth return values.

If the function returns nil, the object will not be moved. This is useful if the script has not yet collected all the information it needs to give the correct answer, or in temporary cases where you want the object to stay where it is.

Parameters
function: function
Function for monitoring DragContinue signals. This function receives the signal's screen space input position and returns a UDim2 and float containing the desired motion of the drag in the desired space and relativity. If this function returns nil, the object will not be moved.

Returns
()
View all inherited from Instance
View all inherited from Object
Events
DragContinue
Fires when a user continues dragging the UI element after DragStart has been initiated.

Parameters
inputPosition: Vector2
Vector2 representing the current input position.

DragEnd
Fires when a user stops dragging the UI element.

Parameters
inputPosition: Vector2
Vector2 representing the current input position.

DragStart
Fires when a user starts dragging the UI element.

Parameters
inputPosition: Vector2
Vector2 representing the current input position.
