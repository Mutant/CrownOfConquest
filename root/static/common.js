// Remove all rows from a table.
function clearTable(tableID) {
    curRows = document.getElementById(tableID).rows;
    if (curRows.length > 0) {    
        for (count = 0; count <= curRows.length; count++) {
            document.getElementById(tableID).deleteRow(0);
        }
    }
}

function byId(id){
    return document.getElementById(id);
}

      

var MAX_DUMP_DEPTH = 10;
      

function dumpObj(obj, name, indent, depth) {
        if (depth > MAX_DUMP_DEPTH) {
                return indent + name + ": <Maximum Depth Reached>\n";
        }

        if (typeof obj == "object") {
                var child = null;
                var output = indent + name + "\n";
                indent += "\t";

                for (var item in obj)
                {
                    try {
                            child = obj[item];
                    } catch (e) {
                            child = "<Unable to Evaluate>";
                    }

                    if (typeof child == "object") {
                            //output += dumpObj(child, item, indent, depth + 1);
                    } else {
                            output += indent + item + ": " + child + "\n";
                    }
                }

                return output;
        } else {
                return obj;
        }
}