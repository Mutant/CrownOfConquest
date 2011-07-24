/* Load Dojo */

dojo.registerModulePath("rpg", urlBase + "static/dojo_cust/rpg");

dojo.require("dojo.parser");
dojo.require("dijit.layout.TabContainer");
dojo.require("dijit.form.FilteringSelect");
dojo.require("dijit.Dialog");
dojo.require("dijit.form.DropDownButton");
dojo.require("dijit.Menu");
dojo.require("dijit.form.NumberTextBox");
dojo.require("dijit.form.Button");
dojo.require("dijit.layout.ContentPane");
dojo.require("dijit.Dialog");
dojo.require("dijit.form.TextBox");
dojo.require("dojox.layout.ContentPane");
dojo.require('dijit.Tooltip');
dojo.require("dojo.dnd.Source");
dojo.require("dijit.form.NumberSpinner");
dojo.require("rpg.dnd.Target");
dojo.require("dijit.form.Form");


/* Map Movement */

var mapDimensions;
function shiftMapCallback(data) {
	var xShift = data.xShift;
	var yShift = data.yShift;
	mapDimensions = data.mapDimensions;

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
		
		var new_y = coords.y+adjustment;
				
		var newCoords = {		
			x: coords.x,
			y: new_y
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
			
			var new_x = coords.x+((position=='prepend') ? -1 : 1);

			var newCoords = {		
				x: new_x,
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
		
	var startX = parseInt(newSector.x)-1;
	var endX = parseInt(newSector.x)+1;
	var startY = parseInt(newSector.y)-1;
	var endY = parseInt(newSector.y)+1;
	
	for(var x=startX; x <= endX; x++) {
		for(var y=startY; y <= endY; y++) {
			var link = dojo.byId("sector_link_" + x + "_" + y);
			
			if (link) {
				enableLink(link);
			}
		}	
	}
	
	disableLink(dojo.byId("sector_link_" + newSector.x + "_" + newSector.y));
	
	if (data.xShift != 0) {
		x = (data.xShift == 1) ? parseInt(newSector.x) - 2 : parseInt(newSector.x) + 2;
		for(var y=startY; y <= endY; y++) {
			var link = dojo.byId("sector_link_" + x + "_" + y);
			
			if (link) {
				disableLink(link);
			}
		}
	}
	if (data.yShift != 0) {
		y = (data.yShift == 1) ? parseInt(newSector.y) - 2 : parseInt(newSector.y) + 2;
		for(var x=startX; x <= endX; x++) {
			var link = dojo.byId("sector_link_" + x + "_" + y);
			
			if (link) {
				disableLink(link);
			}
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
			if (sectorsAdded[val][i].x >= mapDimensions.min_x && sectorsAdded[val][i].x <= mapDimensions.max_x &&
			    sectorsAdded[val][i].y >= mapDimensions.min_y && sectorsAdded[val][i].y <= mapDimensions.max_y) {
		
				qString += val + '=' + sectorsAdded[val][i].x + "," + sectorsAdded[val][i].y + "&"
			} 
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

	    timeout: 45000	
    });    
}

/* Panels */
var originalContent;
function getPanels(url) {    
	originalContent = dojo.byId('messages-pane').innerHTML;
	
	dijit.byId('messages-pane').setContent('Loading...');
    
    var no_cache = "&no_cache=" + Math.random() *100000000000;
    
    if (url.indexOf('?') == -1) {
    	no_cache = '?' + no_cache;
    }
    
	dojo.xhrGet( {
        url: urlBase + url + no_cache,
        handleAs: "json",        
        load: panelLoadCallback,        
        error: panelErrorCallback,
	    timeout: 45000
    });
}

function postPanels(form) {
	originalContent = dojo.byId('messages-pane').innerHTML;
	
	dojo.xhrPost( {
        form: form,
        handleAs: "json",        
        load: panelLoadCallback,        
        error: panelErrorCallback,
	    timeout: 45000
    });	
    
    return false;
}

function panelLoadCallback(responseObject, ioArgs) {
	if (responseObject.error) {
		dojo.byId('error-message').innerHTML = responseObject.error;
		dijit.byId('error').show();
		dijit.byId('messages-pane').setContent(originalContent);
	}
					
	refreshPanels(responseObject);

	displayPopupMessages();	
	
	if (responseObject.displayDialog) {
		dijit.byId(responseObject.displayDialog).show();
	}
	
	if (responseObject.panel_callbacks) {
		executeCallbacks(responseObject.panel_callbacks);
	}
	
	dojo.byId('map-outer').style.visibility = 'visible';
	dojo.byId('messages-pane').style.visibility = 'visible';
	dojo.byId('main-loading').style.display = 'none';
}

function panelErrorCallback(err) {
	errorMsg = "An error occurred processing the action. Please <a href=\"" + urlBase + "\">try again</a> or report a bug.";
	dijit.byId('messages-pane').setContent(errorMsg);
}

function refreshPanels(panelData) {
	if (panelData.redirect) {
		console.log(panelData.redirect);
		document.location = panelData.redirect;
		return;
	}

	if (panelData.panel_messages) {
		displayMessages(panelData.panel_messages);
	}
	
	if (panelData.screen_to_load) {
		if (panelData.screen_to_load == 'close') {
			closeScreen();
		}
		else {
			loadScreen(panelData.screen_to_load);
		}
	}
	
	var messagesLoaded = false;
				
    if (panelData.refresh_panels) {
		for (var panel in panelData.refresh_panels) {	
			dijit.byId(panel+'-pane').setContent(panelData.refresh_panels[panel]);

			if (panel == 'party') {
				createMenus();
			}
			
			if (panel == 'messages') {
				messagesLoaded = true;
			}
		}
	}
	
	if (! messagesLoaded) {
		dijit.byId('messages-pane').setContent(originalContent);
	}
	else {
		setMessagePanelSize(panelData.message_panel_size);
	}
}

function displayPopupMessages() {
	if (dojo.trim(dojo.byId('popup-messages-pane').innerHTML)) {
		show_message(dojo.byId('popup-messages-pane').innerHTML);
		dojo.byId('popup-messages-pane').innerHTML = '';
	}
}

var panel_messages;
var displayCount = 0;	
function displayMessages(messages_passed) {
	if (messages_passed) {
		panel_messages = messages_passed;
	}
	
	if (! panel_messages) {
		return;
	}
	
	if (panel_messages[displayCount]) {
		dojo.byId('party-message-text').innerHTML = panel_messages[displayCount];
		dijit.byId('party-message').show();
		displayCount++;
	}
	else {
		dijit.byId('party-message').hide();
		displayCount = 0;
	}
}

function executeCallbacks(callBacks) {
	for (var callIdx in callBacks) {
		callback = callBacks[callIdx];
		
		var callbackName = callback.name + "Callback"
		window[callbackName](callback.data);		
	}
}

var current_size = 'small';
function setMessagePanelSize(size) {
	if (size == 'large' && current_size == 'small') {
		dojo.byId('messages-pane').style.overflow = 'hidden';
		dojo.animateProperty({
		  node:"messages-pane",
		  duration: 400,		  
		  properties: {
		      left: 80,
		      bottom: 80,
		      top: 80,
		      right: 80,
		  }
		}).play();
	
		dojo.byId('messages-pane').style.width = "80%";
	
		dojo.byId('messages-pane').style.opacity = "0.9";
		dojo.byId('messages-pane').style.overflow = 'auto';
		current_size = 'large';
	}
	
	if (size == 'small' && current_size == 'large') {
		dojo.byId('messages-pane').style.top = "";
		dojo.byId('messages-pane').style.right = "";
		dojo.byId('messages-pane').style.bottom = '20px';
		dojo.byId('messages-pane').style.left = '20px';
		dojo.byId('messages-pane').style.opacity = "0.8";
		dojo.byId('messages-pane').style.width = "auto";
		current_size = 'small';		
	}
	
} 

function dungeonCallback(data) {
	var updatedSectors = data.sectors;
	for (var x in updatedSectors) {
		for (var y in updatedSectors[x]) {
			if (updatedSectors[x][y]) {
				sector = updatedSectors[x][y];
			
				var sector_id = "sector_" + x + "_" + y;
			
				if (! dojo.byId(sector_id)) {
					// Create sector
					newSector = document.createElement("div");
					newSector.setAttribute('id', sector_id);
					newSector.style.position = 'absolute';					
					newSector.style.top = (y - data.boundaries.min_y) * 40;
					newSector.style.left = (x - data.boundaries.min_x) * 40; 
					newSector.style.width = '40px';
					newSector.style.height = '40px';
					dojo.byId('dungeon_outer').appendChild(newSector); 
				}

				dojo.byId(sector_id).innerHTML = sector.sector;
				
				if (dijit.byId('cgtt_' + x + '_' + y)) {
					dijit.byId('cgtt_' + x + '_' + y).destroyRecursive();
				}					
				if (sector.cg_desc) {
					params = {
						connectId: [sector_id],
						label: sector.cg_desc,
						id: 'cgtt_'+ x + '_' + y
					};		
					new dijit.Tooltip(params);
				}
				
				if (dijit.byId('ptt_' + x + '_' + y)) {
					dijit.byId('ptt_' + x + '_' + y).destroyRecursive();
				}					
				if (sector.party_desc) {
					params = {
						connectId: [sector_id],
						label: sector.party_desc,
						id: 'ptt_' + x + '_' + y
					};		
					new dijit.Tooltip(params);				
				}		
			}		 
		}	
	}
	
	dungeonScroll(data.scroll_to); 
}

function dungeonRefreshCallback(scroll_to) {
	dungeonScroll(scroll_to); 
}

function dialogCallback(data) {
	dojo.byId('dialog-content').innerHTML = data.content;
	
	if (data.parse_content) {
		dojo.parser.parse('dialog-content');
	}	
	
	dijit.byId('dialog').attr('execute', function() { dialogSubmit(data.submit_url) });
	dijit.byId('dialog').attr('title', data.dialog_title);
	dijit.byId('dialog').show();
}

function dialogSubmit(submitUrl) {
	var form = dijit.byId('dialog').attr('value');

	var submitString = '';
	for(var prop in form) {
	    if(form.hasOwnProperty(prop))
	        submitString += prop + '=' + form[prop] + '&';
	}
	
	getPanels(submitUrl + '?' + submitString);
}

/* Screen */

function loadScreen(url) {
	if (dojo.byId('screen-outer').style.display == 'none') {
		dojo.byId('screen-outer').style.display = 'block';
	}
	
	dojo.xhrGet( {
        url: urlBase + url,
        handleAs: "text",
        
        load: function(response){	
        	dijit.byId('screen-pane').set("content", response);
        }
    });
}

function closeScreen() {
	dojo.byId('screen-outer').style.display = 'none';
	dijit.byId('screen-pane').set("content", '');
}

/* Options */

function toggle_disabled_checkboxes() {
	setting = dojo.byId('send_email').checked ? false : true;
	dojo.byId('send_daily_report').disabled = setting;
	dojo.byId('send_email_announcements').disabled = setting;
}

/* Layout */
function unselectImage(name){
    document[name].src = images[name + "-unsel"].src;
    return true;
}
function selectImage(name){
    document[name].src = images[name + "-sel"].src;
    return true;
}

/* Character */

var displayed;
function displayCharList(display) {
	if (displayed) {
		dojo.byId('character-list-' + displayed).style.display = 'none';
		dojo.byId('character-list-link-' + displayed).style.background = 'none';
	}
	dojo.byId('character-list-' + display).style.display = 'inline';
	dojo.byId('character-list-link-' + display).style.background = '#6C6FB5';
	displayed = display;
}

/* Mini-map */


function setMapBoxCallback(mapBoxCoords) {
	var top = parseInt(mapBoxCoords.top_y) * 2;
	var left = parseInt(mapBoxCoords.top_x) * 2;
	var width = parseInt(mapBoxCoords.x_size) * 2;		
	var height = parseInt(mapBoxCoords.y_size) * 2;
	
	var box = dojo.byId('minimap-view-box');
	
	box.style.top = top + 'px';
	box.style.left = left + 'px';
	box.style.width = width + 'px';
	box.style.height = height + 'px';
	
	box.style.display = 'block';
}

function hideKingdomMap() {
	dojo.byId('minimap').style.display = 'none';
	dojo.byId('hide-kingdom-map-link').style.display = 'none';
	dojo.byId('show-kingdom-map-link').style.display = 'inline';
	dojo.byId('center-party-link').style.display = 'none';
	dojo.byId("minimap-display").innerHTML = '';
	
	dojo.xhrGet( {
        url: urlBase + "map/change_mini_map_state?state=closed",
        handleAs: "json",
	    timeout: 45000
    });
}

function showKingdomMap() {
	dojo.byId('minimap').style.display = 'block';
	dojo.byId('hide-kingdom-map-link').style.display = 'inline';
	dojo.byId('show-kingdom-map-link').style.display = 'none';
	dojo.byId('center-party-link').style.display = 'inline';
	
	dojo.xhrGet( {
        url: urlBase + "map/change_mini_map_state?state=open",
        handleAs: "json",
	    timeout: 45000
    });	
}

function miniMapClick(evt) {
	var coords = findMiniMapCoords(evt);

	getPanels('map/search?x=' + coords.x + '&y=' + coords.y);
}


function miniMapMove(evt) {
	var coords = findMiniMapCoords(evt);
	
	if (! coords.x || ! coords.y) {
		dojo.byId('minimap-display').innerHTML = '';
		return;
	}
	
	var kingdom = kingdoms_data[coords.x][coords.y];
	if (kingdom) {
		kingdom = "Kingdom of " + kingdom;
	}
	else {
		kingdom = "Neutral";
	}
	
	kingdom += " (" + coords.x + ", " + coords.y + ")";
	
	dojo.byId('minimap-display').innerHTML = kingdom;

}

function findMiniMapCoords(evt) {
	var pixelX = evt.layerX;
	var pixelY = evt.layerY;

	if (evt.target.id == 'minimap-view-box') {
		var box = dojo.byId('minimap-view-box');
	
		pixelX = pixelX + parseInt(box.style.left);
		pixelY = pixelY + parseInt(box.style.top); 
	}

	var coords = {};
	coords.x = Math.floor(pixelX/2);
	coords.y = Math.floor(pixelY/2);
	
	return coords;
}

var kingdoms_data;
function setKingdomsData(data) {
	kingdoms_data = data;
}

function miniMapInitCallback() {
	dojo.connect(dojo.byId("minimap"), "onmousemove", window, "miniMapMove");
	dojo.connect(dojo.byId("minimap"), "onclick", window, "miniMapClick");

	dojo.xhrGet( {
        url: urlBase + "map/kingdom_data",
        handleAs: "json",
        
        load: function(responseObject){
        	setKingdomsData(responseObject);			
		},

	    timeout: 45000
    });
}

	