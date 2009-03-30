dojo._xdResourceLoaded({
	depends: [["provide", "rpg.dnd.Target"]],
	defineResource: function(dojo){
		if (!dojo._hasResource["rpg.dnd.Target"]) {
			dojo._hasResource["rpg.dnd.Target"] = true;
			dojo.provide("rpg.dnd.Target");
			dojo.declare("rpg.dnd.Target", dojo.dnd.Target, {
				onDndDrop: function(source, nodes, copy){
					if (this.containerState == "Over") { // dropping on us
						source.delItem('dojoUnique1'); // delete the copied item
					}
					this.onDndCancel(); // cleanup the drop state
				},
				
				markupFactory: function(params, node){
					params._skipStartup = true;
					return new rpg.dnd.Target(node, params);
				}
			})
		}
	}
});
