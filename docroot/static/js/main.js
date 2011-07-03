function shiftMapCallback(data) {
	var xShift = data.xShift;
	var yShift = data.yShift;

	console.log("xShift: " + xShift + "; yShift: " + yShift);
	
	var sectorsAdded = {};

	if (yShift == 1) {
		removeFirstNonTextNode(dojo.byId('map-holder'));
		sectorsAdded.row = addEmptyRow(data.xGridSize, 'append');
	}
	if (yShift == -1) {
		removeLastNonTextNode(dojo.byId('map-holder'));
		sectorsAdded.row = addEmptyRow(data.xGridSize, 'prepend');
	}
	if (xShift == 1) {
		var rowsList = dojo.byId('map-holder').childNodes;
		for (i=0; i<rowsList.length; i++) {
			var row = rowsList.item(i);
			if (row.nodeName != '#text') {
				removeFirstNonTextNode(row);
			}
		}
		sectorsAdded.column = addEmptyColumn(data.yGridSize, 'append');
	}
	if (xShift == -1) {
		var rowsList = dojo.byId('map-holder').childNodes;
		for (i=0; i<rowsList.length; i++) {
			var row = rowsList.item(i);
			
			if (row.nodeName != '#text') {
				removeLastNonTextNode(row);
			}
		}
		sectorsAdded.column = addEmptyColumn(data.yGridSize, 'prepend');
	}
	
	moveLinks(data);
	
	var newSector = dojo.byId('sector_' + data.newSector.x + '_' + data.newSector.y); 
	
	newSector.appendChild(dojo.byId('herecircle'));	
	
	loadNewSectors(sectorsAdded);
}

function removeFirstNonTextNode(parent) {
	removeNonTextNode(parent, 'firstChild');
}

function removeLastNonTextNode(parent) {
	removeNonTextNode(parent, 'lastChild');
}

function removeNonTextNode(parent, property) {
	var node = getNonTextNode(parent, property);
	parent.removeChild(node);
}

function getNonTextNode(parent, property) {
	var node = parent[property];
	while (node.nodeName == '#text') {
		parent.removeChild(node);
		node = parent[property];
	}
	
	return node;
}

function addEmptyRow(rowSize, position) {
	var newRow = document.createElement('div');
	newRow.setAttribute('class', 'map-row');

	var map = dojo.byId('map-holder');

	var adjacentRow;
	var adjustment;

	if (position == 'prepend') {
		adjacentRow = getNonTextNode(map, 'firstChild');	
		adjustment = -1;
		map.insertBefore(newRow, map.firstChild);
	}
	else if (position == 'append') {
		adjacentRow = getNonTextNode(map, 'lastChild');
		adjustment = 1;
		map.appendChild(newRow);
	}
	
	var adjacentChildren = adjacentRow.childNodes;
	
	var sectorsAdded = [];
	
	for(i=0; i<rowSize; i++) {
		var adjacentSector = adjacentChildren.item(i);
		while (adjacentSector.nodeName == '#text') {
			adjacentRow.removeChild(adjacentSector);
			adjacentSector = adjacentChildren.item(i);
		}
		var coords = getSectorsCoords(adjacentSector);
		
		var newCoords = {		
			x: coords.x,
			y: coords.y+adjustment
		};
		
		sectorsAdded.push(newCoords);
				
		var newSpan = newSector(newCoords.x, newCoords.y);
		
		newRow.appendChild(newSpan);
	}
	
	return sectorsAdded;
}

function addEmptyColumn(colSize, position) {
	var map = dojo.byId('map-holder');
	
	var rowsList = map.childNodes;
	
	var sectorsAdded = [];
	
	for (i=0; i<rowsList.length; i++) {
		var row = rowsList.item(i);
		
		if (row.nodeName != '#text') {
			var adjacentSector = getNonTextNode(row, (position=='prepend') ? 'firstChild' : 'lastChild');
			var coords = getSectorsCoords(adjacentSector);			
		
			var newCoords = {		
				x: coords.x+((position=='prepend') ? -1 : 1),
				y: coords.y
			};
			
			sectorsAdded.push(newCoords);
		
			var newSpan = newSector(newCoords.x, newCoords.y);
			
			if (position == 'prepend') {
				row.insertBefore(newSpan, row.firstChild);
			}
			else if (position == 'append') {
				row.appendChild(newSpan);
			}
		}
	}
	
	return sectorsAdded;
}

function newSector(x, y) {
	var newSpan = document.createElement('span');
	newSpan.setAttribute('class','sector-outer');
	newSpan.id="outer_sector_" + x + "_" + y;
	
	return newSpan;
}

function moveLinks(data) {
	var newSector = data.newSector;
	
	//console.log(newSector);
	
	var startX = parseInt(newSector.x)-1;
	var endX = parseInt(newSector.x)+1;
	var startY = parseInt(newSector.y)-1;
	var endY = parseInt(newSector.y)+1;
	
	//console.log("startX: " + startX + ", endX: " + endX + ", startY: " + startY + ", endY: " + endY);

	for(var x=startX; x <= endX; x++) {
		for(var y=startY; y <= endY; y++) {
			//console.log("Updating link for sector " + x + ", " +y);
			var link = dojo.byId("sector_link_" + x + "_" + y);
			enableLink(link);
		}	
	}
	
	disableLink(dojo.byId("sector_link_" + newSector.x + "_" + newSector.y));
	
	if (data.xShift != 0) {
		x = (data.xShift == 1) ? parseInt(newSector.x) - 2 : parseInt(newSector.x) + 2;
		for(var y=startY; y <= endY; y++) {
			//console.log("Disabling link for sector " + x + ", " +y);
			var link = dojo.byId("sector_link_" + x + "_" + y);
			disableLink(link);
		}
	}
	if (data.yShift != 0) {
		y = (data.yShift == 1) ? parseInt(newSector.y) - 2 : parseInt(newSector.y) + 2;
		for(var x=startX; x <= endX; x++) {
			//console.log("Disabling link for sector " + x + ", " +y);
			var link = dojo.byId("sector_link_" + x + "_" + y);
			disableLink(link);
		}
	}
}

function enableLink(link) {
	link.style.cursor = 'pointer';
	link.onclick = function() { return true; };
}

function disableLink(link) {
	link.style.cursor = 'default';
	link.onclick = function() { return false; };
}

function getSectorsCoords(sector) {
	var parts = sector.id.split(/_/);
	
	return {
		x: parseInt(parts[2]),
		y: parseInt(parts[3]),
	}
}

function loadNewSectors(sectorsAdded) {
	var qString = "";
	for (var val in sectorsAdded) { 
		for(var i=0; i<sectorsAdded[val].length; i++) {
			qString += val + '=' + sectorsAdded[val][i].x + "," + sectorsAdded[val][i].y + "&" 
		}
	}
	
	dojo.xhrGet( {
        url: urlBase + "map/load_sectors?" + qString,
        handleAs: "json",
        
        load: function(responseObject, ioArgs){
        	var herecircle = dojo.byId('herecircle');
        
        	var data = responseObject.sector_data;

			for(var j=0; j<data.length; j++) {
				var coords = data[j].sector.split(',');
				var sector = dojo.byId('outer_sector_' + coords[0] + "_" + coords[1]);
				
				if (sector) {
					sector.innerHTML = data[j].data;
					if (data[j].parse) {
						dojo.parser.parse(sector);					
					}
				}
			}
			
			var newSector = dojo.byId('sector_' + responseObject.loc.x + '_' + responseObject.loc.y); 
	
			newSector.appendChild(herecircle);				
		},

	    timeout: 15000	
    });

		
}