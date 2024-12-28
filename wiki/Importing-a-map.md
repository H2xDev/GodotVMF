1. Create a scene and create inside a new node with class `VMFNode`. 
2. Choose a VMF file to import. Enable the "Use External File" checkbox if you need to browse to a file outside of the Godot resources.
3. Click `import` in the inspector panel or click `Full` in the 3D scene view at the top tool bar.
4. Wait a while...
5. Done!

If you found that something going wrong, check the Output panel first. 
In some cases you can see in the Output panel messages tagged with `[Godot VMF]`. 

## Resources

The "Resource Generation" properties in VMFNode control whether the generated meshes or collision shapes are stored as binary resources inside the project directory (configured via `import.geometryFolder`).
This helps with scene file size and complexity, and improves editor load times.
