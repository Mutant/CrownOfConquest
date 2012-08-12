/* Load Dojo */

dojo.registerModulePath("rpg", urlBase + "static/dojo_cust/rpg");

dojo.require("dojo.parser");
dojo.require("dijit.layout.TabContainer");
dojo.require("dijit.form.Select");
dojo.require("dijit.form.FilteringSelect");
dojo.require("dijit.Dialog");
dojo.require("dijit.form.DropDownButton");
dojo.require("dijit.Menu");
dojo.require("dijit.form.NumberTextBox");
dojo.require("dijit.form.Button");
dojo.require("dijit.layout.ContentPane");
dojo.require("dijit.form.TextBox");
dojo.require("dojox.layout.ContentPane");
dojo.require('dijit.Tooltip');
dojo.require("dojo.dnd.Source");
dojo.require("dijit.form.NumberSpinner");
dojo.require("rpg.dnd.Target");
dojo.require("dijit.form.Form");
dojo.require("dojo.cookie");
dojo.require("dojo.dnd.Moveable");
dojo.require("dojo.data.ItemFileReadStore");

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
        
        load: updateSectors,

	    timeout: 45000	
    });    
}

function updateSectors(responseObject) {
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
}

function refreshSectorCallback(data) {
	updateSectors(data);
}

/* Panels */
var originalContent;
function getPanels(url) {    
	originalContent = dojo.byId('messages-pane').innerHTML;
		
	dijit.byId('messages-pane').set("content", dojo.byId('loader-gif').innerHTML);
    
    var no_cache = "&no_cache=" + Math.random() *100000000000;
    
    if (url.indexOf('?') == -1) {
    	no_cache = '?' + no_cache;
    }
    
    _gaq.push(['_trackPageview', url]);
    
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
	
	if (responseObject.bring_messages_to_front == 1) {
		messagesToFront();
	}
	
	dojo.byId('map-outer').style.visibility = 'visible';
	dojo.byId('messages-pane').style.visibility = 'visible';
	dojo.byId('main-loading').style.display = 'none';
}

function panelErrorCallback(err) {
	errorMsg = "An error occurred processing the action. Please <a href=\"" + urlBase + "\">try again</a> or " + 
		"<a href=\"" + urlBase + "player/submit_bug\" target=\"_blank\">report a bug</a>.";
	dijit.byId('messages-pane').setContent(errorMsg);
	closeScreen();
}

function messagesToFront() {
	dojo.byId('messages-pane').style.zIndex = '700';
}

function messagesToBack() {
	dojo.byId('messages-pane').style.zIndex = '500';
}

function refreshPanels(panelData) {
	if (panelData.redirect) {
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

	if (panel_messages.length == 1) {
		message = panel_messages[0];
	}
	else {
		var message = '<ul style="margin: 0px; padding: 10px">';	
		for (var i = 0; i < panel_messages.length; i++) {
			if (panel_messages[i]) {
				message += '<li>' + panel_messages[i] + '</li>';
			}
		}
		message += '</ul>';
	}

	dojo.byId('party-message-text').innerHTML = message;
	dijit.byId('party-message').show();
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
		dojo.byId('messages-pane').style.top = "80px";
		dojo.byId('messages-pane').style.right = "80px";
		dojo.byId('messages-pane').style.bottom = '80px';
		dojo.byId('messages-pane').style.left = '90px';
		dojo.byId('messages-pane').style.width = "80%";
		dojo.byId('messages-pane').style.height = "70%";
		current_size = 'large';
	}
	
	if (size == 'small' && current_size == 'large') {
		dojo.byId('messages-pane').style.top = "";
		dojo.byId('messages-pane').style.right = "";
		dojo.byId('messages-pane').style.bottom = '20px';
		dojo.byId('messages-pane').style.left = '20px';
		dojo.byId('messages-pane').style.width = "auto";
		dojo.byId('messages-pane').style.height = "auto";
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

function hideDiag(diagName) {
	setTimeout(function() {dijit.byId(diagName).hide()}, 300);
}

/* Screen */
var screenHistory = [];
var currentUrl;
function loadScreen(url, noOnClose) {
	if (dojo.byId('screen-outer').style.display == 'none') {
		dojo.byId('screen-outer').style.display = 'block';
	}

	if (! noOnClose) {
		processOnCloseScreen();
	}
	
	messagesToBack();
		
	dijit.byId('screen-pane').set("content", dojo.byId('loader-gif').innerHTML);

	_gaq.push(['_trackPageview', url]);
	
	screenHistory.push(url);
	currentUrl = url;

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
	screenHistory = [];
	displayed = false;
	
	processOnCloseScreen();
}

function backScreen() {
	if (screenHistory.length == 0) {
		return;
	}
	
	var url = screenHistory.pop();
	if (currentUrl !== undefined) {
		while (url == currentUrl) {
			if (screenHistory.length == 0) {
				
				screenHistory.push(url);
				return;
			}
		
			url = screenHistory.pop();
		}
	}
	
	if (! url) {
		return;
	}
	loadScreen(url);
}

var onCloseScreen = [];

function addOnCloseScreen(onCloseFunc) {
	onCloseScreen.push(onCloseFunc);
}

function processOnCloseScreen() {
	var func;
	while (func = onCloseScreen.pop()) {
		func();
	}
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

function setBrowserSize() {
	var vs = dojo.window.getBox();
	
	dojo.byId('login-height').value = vs.h;
	dojo.byId('login-width').value = vs.w;
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
	var pixelCoords = getXYFromEvent(evt);
	
	if (evt.target.id == 'minimap-view-box') {
		var box = dojo.byId('minimap-view-box');
	
		pixelCoords.x = pixelCoords.x + parseInt(box.style.left);
		pixelCoords.y = pixelCoords.y + parseInt(box.style.top); 
	}

	var coords = {};
	coords.x = Math.floor(pixelCoords.x/2);
	coords.y = Math.floor(pixelCoords.y/2);
		
	return coords;
}

function getXYFromEvent(evt) {
	var x; var y;
	
	var coords = {};
	
	if (evt.layerX) {
		coords.x = evt.layerX;
		coords.y = evt.layerY;
	}
	else {
		coords.x = evt.x;
		coords.y = evt.y;
	}
	
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

function setMinimapVisibilityCallback(data) {
	if (data == 1) {
		dojo.byId('mini_map-pane').style.display = 'block';
	}
	else { 
		dojo.byId('mini_map-pane').style.display = 'none';
	}
}

/* Quests */

function acceptQuest(quest_id) {
	dojo.xhrGet( {
        url: urlBase + "/quest/accept?quest_id=" + quest_id, 
        handleAs: "json",
        
        load: function(responseObject, ioArgs) {
        	if (responseObject.message) {
        		dojo.byId('accept-message-text').innerHTML = responseObject.message;
        		dijit.byId('message').show();
        	}
        
        	if (responseObject.accepted) {
        		dojo.byId('offer').innerHTML = dojo.byId('accepted').innerHTML;
        	}
        }
    });
}

/* Combat */

function postRoundCallback() {
	dojo.xhrGet( {
        url: urlBase + 'combat/refresh_combatants',
        handleAs: "json",        
        load: function(responseObject, args) {
        	dijit.byId('party-pane').setContent(responseObject.refresh_panels.party);
        	dijit.byId('creatures-pane').setContent(responseObject.refresh_panels.creatures);
        	createMenus();
        },
        error: panelErrorCallback,
	    timeout: 45000,
	    preventCache: true	    
    });
}
	
/* Kingdoms */
var selectedKingdom;
function viewKingdomInfo(kingdomId) {
	if (selectedKingdom) {
		dojo.byId('kingdom-link-' + selectedKingdom).style.backgroundColor = '';
	}

	dojo.byId('kingdom-link-' + kingdomId).style.backgroundColor = '#5F5F5F';
	selectedKingdom = kingdomId;

	dojo.xhrGet( {
        url: urlBase + "party/kingdom/individual_info?kingdom_id=" + kingdomId,
        handleAs: "text",
        
        load: function(responseObject){
			dojo.byId('kingdom-info').innerHTML = responseObject;
		},

	    timeout: 45000
    });	
}

/* Equipment */
function clearDropSectors(coord, item, gridIdPrefix) {
	var sectors = findDropSectors(coord, item, gridIdPrefix);
	for (var i = 0; i < sectors.length; i++) {
		sectors[i].removeClass('item-droppable');
		sectors[i].removeClass('item-blocked');
	}
}

function findDropSectors(coord, item, gridIdPrefix) {
	var startX = parseInt(coord.x);
	var endX   = parseInt(coord.x) + parseInt(item.attr('itemWidth'));
	var startY = parseInt(coord.y);
	var endY   = parseInt(coord.y) + parseInt(item.attr('itemHeight'));
		
	var sectors = [];
	
	for (var x = startX; x < endX; x++) {
		for (var y = startY; y < endY; y++) {
			sectors.push($( "#" + gridIdPrefix + "-" + x + "-" + y ));
		}
	}
	
	return sectors;
}

var over;
var grid;

function dragItemOver(event, ui, hoverSector, dropAlwaysAllowed) {
	var item = ui.draggable;
			
	var currentCoord = {
		x: parseInt(hoverSector.attr('sectorX')),
		y: parseInt(hoverSector.attr('sectorY')),
	}
	
	if (typeof over != 'undefined' && (over.x != currentCoord.x || over.y != currentCoord.y)) {
		clearDropSectors(over, item, hoverSector.attr("idPrefix"));
	}
			
	over = currentCoord;
	
	if (typeof grid != 'undefined' && grid != hoverSector.attr('grid')) {
		$('.'+grid).removeClass('item-droppable').removeClass('item-blocked');
	}
	grid = hoverSector.attr('grid');
		
	var sectors = findDropSectors(currentCoord, item, hoverSector.attr("idPrefix"));
	
	var canDrop = dropAlwaysAllowed ? true : canDropOnSectors(sectors, item);
	
	for (var i = 0; i < sectors.length; i++) {		
		sectors[i].addClass(canDrop ? 'item-droppable' : 'item-blocked');
	}
}

function dragItemOut(event, ui, hoverSector) {
	var item = ui.draggable;
	
	var currentCoord = {
		x: parseInt(hoverSector.attr('sectorX')),
		y: parseInt(hoverSector.attr('sectorY')),
	}
	
	if (typeof over != 'undefined' && over.x == currentCoord.x && over.y == currentCoord.y) {
		clearDropSectors(over, item, hoverSector.attr("idPrefix"));
		over = undefined;
	}	
}

function dropItemOnGrid(event, ui, hoverSector, charId) {
	var item = ui.draggable;
	
	dropItem(item, hoverSector, charId);
}

function dropQuantityItem(params) {
	var item = $('#item-'+params.purchasing_item_id);
	
	var newItem = $(item).clone();
	newItem.attr('id', 'item-quantity-new');
	var hoverSector = $('#'+params.purchasing_item_sector);	
	
	if (newItem.hasClass('shop-item')) {		
		dropItem(newItem, hoverSector, params.purchasing_char_id, params.quantity);
	}
	else {
		sellItem(newItem, params.purchasing_shop_id, hoverSector, params.quantity);
		item.attr('rel', item.attr('rel') + '&no_cache=' + Math.random() *100000000000);
		setupItemTooltips('#' + item.attr('id'));
	}
}

function dropItem(item, hoverSector, charId, quantity, extra) {
	grid = undefined;
		
	var currentCoord = {
		x: parseInt(hoverSector.attr('sectorX')),
		y: parseInt(hoverSector.attr('sectorY')),
	}
	
	var origLoc = item.parent();
		
	var sectors = findDropSectors(currentCoord, item, hoverSector.attr("idPrefix"));
	
	var canDrop = canDropOnSectors(sectors, item);
	
	if (! canDrop) {
		$(item).detach().css({top: 0, left: 0}).appendTo(origLoc);
		clearDropSectors(over, item, hoverSector.attr("idPrefix"));
		return;
	}
	
	var params = { item_id: item.attr('itemId'), character_id: charId, grid_x: currentCoord.x, grid_y: currentCoord.y, tab: hoverSector.attr('tab') };
	
	if (item.hasClass('inventory-item')) {
		if (hoverSector.attr('grid') === 'inventory') {
			$.post(urlBase + 'character/move_item', params, function(data) {
				loadCharStats(charId);
			});
		}
		if (hoverSector.attr('grid') === 'garrison') {
			params.garrison_id = extra.garrisonId;
			$.post(urlBase + 'garrison/transfer_item', params);
			item.removeClass('inventory-item');
			item.addClass('garrison-item');
		}					
	}
	else if (item.hasClass('garrison-item')) {		
		if (hoverSector.attr('grid') === 'inventory') {
			$.post(urlBase + 'garrison/transfer_item', params);
			item.removeClass('garrison-item');
			item.addClass('inventory-item');
		}
		if (hoverSector.attr('grid') === 'garrison') {
			params.garrison_id = extra.garrisonId;
			$.post(urlBase + 'garrison/move_item', params);
		}
	}
	else {		
		var url = 'shop/buy_item';
		if (typeof quantity !== 'undefined') {
			params.quantity = quantity;
			url = 'shop/buy_quantity_item';
		}
			
		getPanels(url + '?' + $.param(params));
		
		item.removeClass('shop-item');
		item.addClass('inventory-item');
		
		createInventoryMenu();
	}
	
	$(item).detach().css({top: 0,left: 0}).appendTo(hoverSector);
	
	for (var i = 0; i < sectors.length; i++) {
		sectors[i].removeClass('item-droppable');
		sectors[i].removeClass('item-blocked');
		sectors[i].attr('hasItem', item.attr("itemId"));
	}
			
	if (origLoc.hasClass('equip-slot')) {
		origLoc.html(origLoc.attr('slotName'));
	}
	else {	
		var origCoord = {
			x: parseInt(origLoc.attr('sectorX')),
			y: parseInt(origLoc.attr('sectorY')),	
		}
		
		var sectors = findDropSectors(origCoord, item, origLoc.attr("idPrefix"));
		for (var i = 0; i < sectors.length; i++) {
			sectors[i].attr('hasItem', '0');
		}
	}
}

function dropItemOnEquipSlot(event, ui, slot, charId) {
	var item = ui.draggable;
	
	var origLoc = item.parent();
	var origCoord = {
		x: parseInt(origLoc.attr('sectorX')),
		y: parseInt(origLoc.attr('sectorY')),	
	}	
	
	var sectors = findDropSectors(origCoord, item, origLoc.attr("idPrefix"));
	for (var i = 0; i < sectors.length; i++) {
		sectors[i].attr('hasItem', '0');
	}	

	var params = { item_id: item.attr('itemId'), character_id: charId, equip_place: slot.attr('slot') };
	
	var existingItem = slot.children().first();
	if (existingItem.length > 0) {
		var sectors = findSectorsForItem(existingItem, 'inventory');
		
		if (sectors.length < 1) {
			// Couldn't find any space for existing item
			returnItem(item.attr('itemId'));
			$(document).trigger('hideCluetip');
			dojo.byId('error-message').innerHTML = "There is no room in the character's inventory to swap out the old item";
			dijit.byId('error').show();
			return;
		}
				
		$(existingItem).detach().css({top: 0,left: 0}).appendTo(sectors[0]);
		
		for (var i = 0; i < sectors.length; i++) {
			sectors[i].attr('hasItem', existingItem.attr("itemId"));
		}
		
		params.existing_item_x = sectors[0].attr('sectorX');
		params.existing_item_y = sectors[0].attr('sectorY');
	}
	slot.html('');
			
	$(item).detach().css({top: 0, left: 0}).appendTo(slot);
		
	if (item.hasClass('inventory-item')) {
		$.post(urlBase + 'character/equip_item', params, function(data) {
			data.char_id = charId;
			loadCharStats(data.char_id);						
			equipItemCallback(data);
		}, 'json');
	}
	else if (item.hasClass('garrison-item')) {
		$.post(urlBase + 'garrison/transfer_item', params, function(data) {
			data.char_id = charId;					
			equipItemCallback(data);
		}, 'json');	
	}
	else {
		item.removeClass('shop-item');
		item.addClass('inventory-item');
		getPanels('shop/buy_item?' + $.param(params) );
	}
}

function equipItemCallback(data) {

	if (data.extra_items) {
		for (var i = 0; i < data.extra_items.length; i++) {
			var extraItemData = data.extra_items[i];
			
			putItemOnGrid(extraItemData.item_id, parseInt(extraItemData.new_x), parseInt(extraItemData.new_y));

		}
	}
	if (data.no_room) {
		$(document).trigger('hideCluetip');
	
		putItemOnGrid(data.item_id, parseInt(data.x), parseInt(data.y));		
		
		dojo.byId('error-message').innerHTML = "There is no room in the character's inventory to swap out the old item";
		dijit.byId('error').show();
		
		if (data.return_item) {
			var slot = $( '.equip-slot[slot="' + data.slot + '"]' );
			var item = $('#item-' + data.return_item);			
			
			$(item).detach().css({top: 0, left: 0}).appendTo(slot);
		}
		
	}
}

function putItemOnGrid(itemId, x, y) {
	var extraItem = $('#item-' + itemId);
					
	var origCoord = {
		x: x,
		y: y,	
	}
	
	var sectors = findDropSectors(origCoord, extraItem, 'inventory');								
	
	extraItem.detach().css({top: 0,left: 0}).appendTo(sectors[0]);
	
	for (var i = 0; i < sectors.length; i++) {
		sectors[i].attr('hasItem', extraItem.attr("itemId"));
	}
}

function canDropOnSectors(sectors, item) {
	var totalSize = parseInt(item.attr('itemWidth')) * parseInt(item.attr('itemHeight'));
	
	if (totalSize < sectors.length) {
		return false;
	}
	
	var canDrop = true;
	
	for (var i = 0; i < sectors.length; i++) {	
		if (sectors[i].attr("hasItem") != 0 && sectors[i].attr("hasItem") != item.attr("itemId")) {
			canDrop = false;
		}
	}
	
	return canDrop;	
}

function loadCharStats(charId) {
	$( '#stats-panel' ).load(urlBase + "/character/stats?character_id=" + charId);
}

function findSectorsForItem(item, grid) {
	var empty = $( '#' + grid + '-grid' ).children('[hasItem="0"]');
	
	var itemHeight = parseInt(item.attr('itemHeight'));
	var itemWidth = parseInt(item.attr('itemWidth'));
		
	var emptyGrid = {};
	
	empty.each(function(){
		var emptySector = $(this);
				
		if (typeof emptyGrid[emptySector.attr('sectorX')] == 'undefined') {
			emptyGrid[emptySector.attr('sectorX')] = {};
		}
		
		emptyGrid[emptySector.attr('sectorX')][emptySector.attr('sectorY')] = emptySector;
	});
	
	var sectors = [];
	
	empty.each(function(){
		var emptySector = $(this);
		
		var startX = parseInt(emptySector.attr('sectorX'));
		var startY = parseInt(emptySector.attr('sectorY'));
		var maxX = (startX + itemWidth - 1);
		var maxY = (startY + itemHeight - 1);
				
		for (var x = startX; x <= maxX; x++) {
			for (var y = startY; y <= maxY; y++) {
				if (typeof emptyGrid[x] != 'undefined' && typeof emptyGrid[x][y] != 'undefined') {
					sectors.push(emptyGrid[x][y]);
				}
			}
		}
				
		if (sectors.length >= (itemHeight*itemWidth)) {
			return false;
		}
		
		sectors = [];
	});	
	
	return sectors;
}

function removeFromGrid(itemId,deleteItem) {
	var item = $( '#item-' + itemId );
	
	var origLoc = item.parent();
	var origCoord = {
		x: parseInt(origLoc.attr('sectorX')),
		y: parseInt(origLoc.attr('sectorY')),	
	}

	var sectors = findDropSectors(origCoord, item, origLoc.attr("idPrefix"));
	for (var i = 0; i < sectors.length; i++) {
		sectors[i].attr('hasItem', '0');
	}
	
	if (deleteItem) {
		item.remove();
		$(document).trigger('hideCluetip');
	}
}

function returnItem(itemId) {
	var item = $( '#item-' + itemId );
	
	var origLoc = item.parent();

	$(item).detach().css({top: 0,left: 0}).appendTo(origLoc);
}
/* Character Inventory */

function organiseInventory(charId) {
	$.get(urlBase + 'character/organise_inventory', { character_id: charId }, function(data) {
		$( '#inventory-outer' ).html(data);
		setupInventory(charId);
	});
}

function setupInventory(charId, inShop) {
	$( ".inventory-item" ).draggable({
		revert: "invalid",
		drag: function( event, ui ) {
			$(document).trigger('hideCluetip');
		},
	});
	
	$( ".inventory-item[isQuantity=1]" ).draggable("option", 'helper', 'clone');	
	
	$( ".inventory" ).droppable({
		accept: ".inventory-item, .shop-item, .garrison-item",
		drop: function( event, ui ) {
			var item = ui.draggable;
		
			if (item.hasClass('shop-item') && item.attr('isQuantity') == 1) {
				dojo.byId('quantity-selection-message').innerHTML = "How many would you like to buy?";
				dojo.byId('quantity-char-id').value = charId;
				dojo.byId('quantity-item-id').value = item.attr('itemId');
				dojo.byId('quantity-spinner').value = 1;
				dojo.byId('quantity-item-sector').value = $(this).attr('id');
				dijit.byId('quantity-selection').show();
			}
			else {
				dropItemOnGrid(event, ui, $(this), charId);
			}
		},
				
		over: function(event, ui) {
			dragItemOver(event, ui, $(this));
		},
		
		out: function(event, ui) {
			dragItemOut(event, ui, $(this));
		},
	});

	setupItemTooltips(".inventory-item");
	createItemMenus();
}

function setupItemTooltips(selector) {
	$(selector).cluetip({cluetipClass: 'tooltip', showTitle: false, cluezIndex: '5000', hoverIntent: {
                      sensitivity:  7,
                      interval:     170,
                      timeout:      0
    },});
}

// Hack to get around dojo deficiency
var currentItemId;
function saveCurrentItemId(id) {
	currentItemId = id;
}
	
function createItemMenus() {
	createInventoryMenu(); 
	createQuantityMenu();
}
	
function createInventoryMenu() { 
	if (dijit.byId('item_inventory_menu') != undefined) {
		dijit.byId('item_inventory_menu').destroyRecursive();			
	}
	
	var itemIds = [];
	$( '.inventory-item' ).each(function(){
		if ($(this).attr('isQuantity') == 0) {
			itemIds.push($(this).attr('id'));
		}	
	});

	var params = {id:"item_inventory_menu", targetNodeIds:itemIds };

	var menu = new dijit.Menu(params,document.createElement("div"));
		
	addCommonMenuItems(menu);	
} 	

function createQuantityMenu() {
	if (dijit.byId('item_quantity_menu') != undefined) {
		dijit.byId('item_quantity_menu').destroyRecursive();			
	}
	
	var itemIds = [];
	$( '.inventory-item' ).each(function(){
		if ($(this).attr('isQuantity') == 1) {
			itemIds.push($(this).attr('id'));
		}	
	});
	
	var params = {id:"item_quantity_menu", targetNodeIds:itemIds };

	var menu = new dijit.Menu(params,document.createElement("div"));
	
	params = {
		label: "Split",
		onClick: function() {
			split_item(currentItemId);
		}
	};
	var splitItem = new dijit.MenuItem(params,document.createElement("div"));
	menu.addChild(splitItem);
	
	addCommonMenuItems(menu);		
}



function give_item_to(char_id, item_id) {
	removeFromGrid(item_id, true);

	dojo.xhrGet( {
        url: urlBase + "character/give_item?item_id=" +  item_id + "&character_id=" + char_id,
        handleAs: "json",	
        load: function(responseObject, ioArgs) {
			loadCharStats(char_id);
        	if (! inCharWindow) {
        		getPanels('party/refresh_party_list');
        	}
        }
    });	       
}

function drop_item_diag(item_id, char_id) {
	dojo.byId('drop-item-id').value = item_id;
	dojo.byId('drop-char-id').value = char_id;
	dijit.byId('drop-item-diag').show();
}

function drop_item(args) {
	var item_id = args.item_id;
	var char_id = args.char_id;
	
	removeFromGrid(item_id, true);

	dojo.xhrGet( {
        url: urlBase + "character/drop_item?item_id=" +  item_id + "&character_id=" + char_id,
        handleAs: "json",	
        load: function(responseObject, ioArgs) {
        	loadCharStats(char_id);
        	if (typeof inCharWindow  === 'undefined' || ! inCharWindow) {        	
        		getPanels('party/refresh_party_list');
        	}
        }
    });	       
}	

function split_item(item_id) {
	dojo.byId('split-item-id').value = item_id;
	dijit.byId('split-diag').show();	
}

function split_item_submit(arguments) {
	var itemId = arguments.item_id;
	dojo.xhrGet( {
        url: urlBase + "character/split_item?item_id=" + itemId + "&new_quantity=" + arguments.new_quantity,
        handleAs: "json",	
        load: function(responseObject) {
        	var item = $( '#item-' + itemId );        
        	var newItem = item.clone(true);
        	newItem.attr('id', 'item-' + responseObject.item_id);
        	newItem.attr('itemId',responseObject.item_id);        	
        
    		var origCoord = {
				x: parseInt(responseObject.new_x),
				y: parseInt(responseObject.new_y),	
			}
			
			var sectors = findDropSectors(origCoord, newItem, 'inventory');						
			
			newItem.css({top: 0,left: 0}).appendTo(sectors[0]);
			
			for (var i = 0; i < sectors.length; i++) {
				sectors[i].attr('hasItem', newItem.attr("itemId"));
			}
			
			item.attr('rel', item.attr('rel') + '&no_cache=' + Math.random() *100000000000);
			setupItemTooltips('#' + item.attr('id'));
			
			newItem.attr('rel', urlBase + 'item/tooltip?item_id=' + responseObject.item_id);
			setupItemTooltips('#' + newItem.attr('id'));
			
			createQuantityMenu();
        }
    });	 	
}

/* Shop */

function setupShop(shopId) {
	$( ".shop-item" ).draggable({
		revert: "invalid",
		drag: function( event, ui ) {
			$(document).trigger('hideCluetip');
		},		
	});
	
	$( ".shop-item[isQuantity=1]" ).draggable("option", 'helper', 'clone');	
	
	$( ".shop" ).droppable({
		accept: ".inventory-item",
		drop: function( event, ui ) {
			var item = ui.draggable;
		
			if (item.attr('isQuantity') == 1) {
				dojo.byId('quantity-selection-message').innerHTML = "How many would you like to sell?";
				dojo.byId('quantity-shop-id').value = shopId;
				dojo.byId('quantity-item-id').value = item.attr('itemId');
				dojo.byId('quantity-spinner').value = item.attr('quantityAvailable');
				dojo.byId('quantity-item-sector').value = $(this).attr('id');
				dijit.byId('quantity-selection').show();
			}
			else {
				sellItemEvent(event, ui,  $(this), shopId);
			}	
		},
				
		over: function(event, ui) {
			dragItemOver(event, ui, $(this), true);
		},
		
		out: function(event, ui) {
			dragItemOut(event, ui, $(this));
		}		
	});
}

function sellItemEvent(event, ui, hoverSector, shopId) {
	var item = ui.draggable;
	
	sellItem(item, shopId, hoverSector);
	
	removeFromGrid(item.attr('itemId'), true);	
}

function sellItem(item, shopId, hoverSector, quantity) {
	var coord = {
		x: parseInt(hoverSector.attr('sectorX')),
		y: parseInt(hoverSector.attr('sectorY')),			
	};
	
	clearDropSectors(coord, item, 'shop');

	var params = { shop_id: shopId, item_id: item.attr('itemId'), quantity: quantity };
	getPanels('shop/sell_item?' + $.param(params) );	
}

function sellCallback(data) {
	if (data.messages) {
		var messages = data.messages;
		var message = "";
		for ( var i in messages ) {
			if (messages[i]) {
				message += messages[i] + '<br>';
			}
		}
		if (message) {
			show_message(message);
		}
	}
	
	if (data.remove_item) {
		removeFromGrid(data.remove_item, true);
	}
	
	if (data.existing_shop_quantity_item) {
		var existingQuan = $( '#item-' + data.existing_shop_quantity_item );
		existingQuan.attr('rel', existingQuan.attr('rel') + '&no_cache=' + Math.random() *100000000000);
		setupItemTooltips('#' + existingQuan.attr('id'));		
	}
}

function quantityPurchaseCallback(data) {
	if ( data.shop_item.quantity <= 0 ) {
		removeFromGrid(data.shop_item.item_id, true);
	}
	
	if (data.item_stacked == '1') {
		removeFromGrid('quantity-new', true);
		
		var stackedOnItem = $( '#item-' + data.stacked_on_item );
		stackedOnItem.attr('rel', stackedOnItem.attr('rel') + '&no_cache=' + Math.random() *100000000000);
		setupItemTooltips('#' + stackedOnItem.attr('id'));	
	}
	else {	
		var item = $( '#item-quantity-new' );
		
		item.attr('itemId', data.inv_item);
		item.attr('id', 'item-' + data.inv_item);
		item.attr('onmouseover', "saveCurrentItemId('" + data.inv_item + "');");
	
		item.attr('rel', urlBase + 'item/tooltip?item_id=' + data.inv_item);
		setupItemTooltips('#' + item.attr('id'));		
		 
		var loc = item.parent();
		var coord = {
			x: parseInt(loc.attr('sectorX')),
			y: parseInt(loc.attr('sectorY')),	
		}		
		
		var sectors = findDropSectors(coord, item, 'inventory');
		
		for (var i = 0; i < sectors.length; i++) {
			sectors[i].attr('hasItem', data.inv_item.item_id);
		}
		
		createQuantityMenu();
	}
	
	var shopItem = $( '#item-' + data.shop_item.item_id );
	shopItem.attr('rel', shopItem.attr('rel') + '&no_cache=' + Math.random() *100000000000);
	setupItemTooltips('#' + shopItem.attr('id'));
}

function loadShopTab(shopId, tab) {
	$.get(urlBase + 'shop/item_tab', { shop_id: shopId, tab: tab }, function(data) {
		$( '#shop-grid' ).html(data);
		setupShop(shopId);
		setupItemTooltips('.shop-item');
	});
}

var shopCharData;

function loadCharShopInventory(charId) {
	if (typeof shopCharData == 'undefined') {
		addOnCloseScreen(function() {
			shopCharData = undefined;
		});
		
		shopCharData = {};
	}

	$( '#char-shop-inventory').html('<img src="' + urlBase + 'static/images/layout/loader.gif">');
	if (typeof shopCharData[charId] != 'undefined') {
		usePreloadedCharInventory(charId);
	}
	else {		
		$( '#char-shop-inventory').load( urlBase + 'shop/character_inventory', { character_id: charId }, function(data) {
			shopCharData[charId] = data;
			shopCharData.currentChar = charId;
		} );
	}
			
	$('.char-shop-link').removeClass('current-selection');
	$('#char-shop-link-'+charId).addClass('current-selection');	
}

function usePreloadedCharInventory(charId) {
	$( '#char-shop-inventory').html(shopCharData[charId]);
	
	setupInventory(charId, true);
	createItemMenus();	
}

/* Garrison */

function setupGarrison(garrisonId) {
	$( ".garrison-item" ).draggable({
		revert: "invalid",
		drag: function( event, ui ) {
			$(document).trigger('hideCluetip');
		},		
	});
	
	$( ".garrison" ).droppable({
		accept: ".garrison-item, .inventory-item",
		drop: function( event, ui ) {
			var item = ui.draggable;
		
			dropItem(item, $(this), '', null, { garrisonId: garrisonId } );
		},
				
		over: function(event, ui) {
			dragItemOver(event, ui, $(this), true);
		},
		
		out: function(event, ui) {
			dragItemOut(event, ui, $(this));
		}		
	});
	
	setupItemTooltips('.garrison-item');
}

function organiseGarrisonEquipment(garrisonId) {
	$.get(urlBase + 'garrison/organise_equipment', { garrison_id: garrisonId }, function(data) {
		$( '#garrison-equipment-outer' ).html(data);
		setupGarrison(garrisonId);
	});
}

function loadGarrisonTab(garrisonId, tab) {
	$.get(urlBase + 'garrison/item_tab', { garrison_id: garrisonId, tab: tab }, function(data) {
		$( '#garrison-equipment-outer' ).html(data);
		setupGarrison(garrisonId);
	});
}

function loadCharGarrisonInventory(charId) {	
	$( '#char-garrison-inventory').html('<img src="' + urlBase + 'static/images/layout/loader.gif">');
	$( '#char-garrison-inventory').load( urlBase + 'garrison/character_inventory', { character_id: charId });
	$('.char-garrison-link').removeClass('current-selection');
	$('#char-garrison-link-'+charId).addClass('current-selection');
}
