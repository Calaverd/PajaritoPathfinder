--- Namespace for the library.
__PAJARITO_MODULE_PATH = (...)..'/'
local Pajarito = {}

Pajarito.Graph = require(__PAJARITO_MODULE_PATH..'Graph')
Pajarito.Node = require(__PAJARITO_MODULE_PATH..'Node')
Pajarito.NodeRange = require(__PAJARITO_MODULE_PATH..'NodeRange')
Pajarito.NodePath = require(__PAJARITO_MODULE_PATH..'NodePath')
Pajarito.heap = require(__PAJARITO_MODULE_PATH..'heap')
Pajarito.directions = require(__PAJARITO_MODULE_PATH..'directions')


return Pajarito