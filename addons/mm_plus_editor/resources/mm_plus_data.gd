@tool
class_name MMPlusData
extends Resource

@export_storage var owner_uid: int = -1
@export_storage var mesh_data : MMPlusMesh
@export_storage var multimesh_data_map : Dictionary[AABB, MultiMesh]
