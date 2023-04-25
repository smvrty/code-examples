var dialog = {
    id: -1,
    style: -1,
    listitem: -1
};

function getElement(id) {
    return document.getElementById(id);
}

document.addEventListener('keydown', (e) => {
    if(dialog.id !== -1) {
        var key = e.key;

        switch(key) {
            case "ArrowUp":
                if(dialog.style == 2 || dialog.style == 4 || dialog.style == 5) {
                    selectListItem(dialog.listitem - 1);
                    e.preventDefault();
                }
                break;
            
            case "ArrowDown":
                if(dialog.style == 2 || dialog.style == 4 || dialog.style == 5) {
                    selectListItem(dialog.listitem + 1);
                    e.preventDefault();
                }
                break;

            case "Enter":
                sendResponse(1);
                // send response
                break;

            case "Escape":
                sendResponse(0);
                // send response
                break;
        }
    }
});

function replaceSpaces(text) {
    while(text.indexOf(' ') !== -1) {
        text = text.replace(' ', '&nbsp;');
    }

    return text;
}

function selectListItem(id) {
    var list = document.getElementsByClassName('dialog-list-item');

    if(id >= 0 && id < list.length) {
        if(dialog.listitem != -1) {
            list[dialog.listitem].classList.toggle('active', 0);
        }

        list[id].classList.toggle('active', 1);
        list[id].scrollIntoView({block: "center"});

        dialog.listitem = id;
    }
}

function pawnToHTML(text) {
    var lines = text.split('\n'),
        lines_length = lines.length,
        last_color = 'FFFFFF';

    var line_colors = [];

    line_colors[0] = last_color;

    for(var line_idx = 0; line_idx < lines_length; line_idx++) {
        var line = lines[line_idx];

        if(line != '') {
            var colors = line.split('{'),
                colors_length = colors.length;

            for(var color_idx = 0; color_idx < colors_length; color_idx++) {
                var color = colors[color_idx];

                if(color[6] == '}') {
                    var color_text = color.substring(0, 6),
                        clean_line = color.substring(7);

                    colors[color_idx] = `<span style="color: #${color_text}">${clean_line}</span>`;

                    if(color_text == undefined) {
                        line_colors[line_idx] = last_color;
                    }
                    else {
                        line_colors[line_idx] = color_text;
                    }
                }
                else if(color_idx != 0) {
                    colors[color_idx] = '{' + color;
                }
            }

            line = colors.join('');

            
            var tabs = line.split('\t'),
                tabs_length = tabs.length,
                tabs_count = 1;

            if(tabs_length > 1) {
                var prev_text = tabs[0];

                //for(var tab_idx = tabs_length - 2; tab_idx >= 0; tab_idx--) {
                for(var tab_idx = 1; tab_idx < tabs_length; tab_idx++) {
                    var tab = tabs[tab_idx];

                    if(tab == '') {
                        tabs_count++;
                    }
                    else {
                        var operator = document.getElementById('width-operator');
                        operator.innerHTML = prev_text;
                        offset = tabs_count * 40 - (operator.offsetWidth % 40);

                        prev_text = tab;

                        tabs[tab_idx] = `<span style="margin-left: ${offset + 1}px">${tab}</span>`;

                        tabs_count = 1;
                    }
                }
            }

            line = tabs.join('');

            if(line_idx > 0) {
                last_color = line_colors[line_idx - 1];
            }

            lines[line_idx] = `<span style="color: #${last_color}">${line}</span>`;
        }
    }

    return lines.join('<br>');
}

function pushContentToList(text, header = false) {
    var lines = text.split('\n'),
        header_elem = getElement('dialog-list-header'),
        list_elem = getElement('dialog-list');

    header_elem.style.display = (header) ? 'block' : 'none';

    if(header == true) {
        var tabs = lines[0].split('\t');

        for(var tab_idx = 0; tab_idx < tabs.length; tab_idx++) {
            var tab = tabs[tab_idx];

            tabs[tab_idx] = `<span class="dialog-list-header-tab list-tab">${pawnToHTML(tab)}</span>`;
        }

        header_elem.innerHTML = tabs.join('');

        lines.splice(0, 1);
    }

	var tabs_count = 0;

    for(var line_idx = 0; line_idx < lines.length; line_idx++) {
        var line = lines[line_idx];

        if(line != '') {
            var tabs = line.split('\t');

			tabs_count = tabs.length;

            for(var tab_idx = 0; tab_idx < tabs.length; tab_idx++) {
                var tab = tabs[tab_idx];

                tabs[tab_idx] = `<span class="dialog-list-item-tab list-tab">${pawnToHTML(tab)}</span>`;
            }

            lines[line_idx] = 
                `<div class="dialog-list-item" onclick="selectListItem(${line_idx})"><span class="dialog-list-item-content">${tabs.join('')}</span></div>`;
        }
    }

    list_elem.innerHTML = lines.join('');

	if(tabs_count > 0) {
		var tabs_width = new Array(tabs_count);
		var tabs = document.getElementsByClassName('list-tab');


		for(var idx = 0; idx < tabs_count; idx++) {
			tabs_width[idx] = 0;
		}

		for(var idx = 0; idx < tabs.length; idx++) {
			var tab_index = (idx % tabs_count),
				tab_width = tabs[idx].offsetWidth;

			if(tab_width > tabs_width[tab_index]) {
				tabs_width[tab_index] = tab_width;
			}
		}

		for(var idx = 0; idx < tabs.length; idx++) {
			var tab_index = (idx % tabs_count);

			tabs[idx].style.width = `${tabs_width[tab_index] + 10}px`;
		}
	}
}

function pawnColorToHTML(text) {
    var color_index = -1;

    do
    {
        color_index = text.indexOf('{');

        if(color_index !== -1) {
            if(text[color_index + 7] == '}') {
                var color = text.substring(color_index + 1, color_index + 7);

                text = text.replace(`{${color}}`, `<span style="color: #${color}">`);
                /*var next_color_index = text.indexOf('{');

                if(next_color_index != -1) {
                    text = text.slice(0, next_color_index) + '</span>' + text.slice(next_color_index);
                }
                else {
                    text += '</span>';
                }*/

                text += '</span>';
            }
        }
    }
    while(color_index !== -1);

    return text;
}

function replacePawnColors(text) {
    var color_lines = text.split('{'),
        lines_length = color_lines.length;

    if(lines_length > 1) {
        for(var idx = 0; idx < lines_length; idx++) {
            var color_line = color_lines[idx];

            if(color_line[6] == '}') { // {ABCDEF} type
                var color = color_line.substring(0, 6),
                    clean_line = color_line.substring(7);
                color_lines[idx] = `<span style="color: #${color}">${clean_line}</span>`;
            }
            else if(idx != 0) {
                color_lines[idx] = '{' + color_line;
            }
        }
    }

    text = color_lines.join('');

    return text;
}

function getTextSize(text) {
    var operator = document.getElementById('width-operator');
    operator.innerHTML = text;

    var offset = operator.offsetWidth;

    return offset;
}

function pawnTextToHTML(text) {
    var lines = replacePawnColors(replaceSpaces(text)).split('\n'),
        lines_length = lines.length;

    for(var line_idx = 0; line_idx < lines_length; line_idx++) {
        var line = lines[line_idx];

        var tab_lines = line.split('\t'),
            tab_count = 0,
            tab_lines_length = tab_lines.length;

        if(tab_lines_length > 1) {
            for(var tab_idx = tab_lines_length - 2; tab_idx >= 0; tab_idx--) {
                var tab_line = tab_lines[tab_idx];

                tab_count++;
                
                if(tab_line != '') {
                    var operator = document.getElementById('width-operator');
                    operator.innerHTML = tab_line;
                    offset = tab_count * 40 - (operator.offsetWidth % 40);

                    tab_lines[tab_idx] = `<span style="margin-right: ${offset + 1}px">${tab_line}</span>`;

                    tab_count = 0;
                }
            }
        }

        lines[line_idx] = tab_lines.join('');
        
        if(line_idx != (lines_length - 1)) {
            lines[line_idx] += '<br>';
        }
    }

    text = lines.join('');

    return text;
}

function showPlayerDialog(dialogid, style, caption, content, button_1, button_2) {
    dialog.id = dialogid;
    dialog.style = style;

    getElement('dialog-caption').innerHTML = pawnToHTML(caption);

	getElement('dialog-button-1').innerHTML = pawnToHTML(button_1);
    getElement('dialog-button-2').style.display = (button_2 !== '') ? 'flex' : 'none';
    getElement('dialog-button-2').innerHTML = pawnToHTML(button_2);

    getElement('dialog').style.display = 'inline-block';

    var content_elem = getElement('dialog-content'),
        list_elem = getElement('dialog-list'),
        input_line_elem = getElement('dialog-input-line');

    getElement('dialog-list-header').style.display = 'none';

    if(style == 0 || style == 1 || style == 3) {
        list_elem.style.display = 'none';

        content_elem.style.display = 'inline-block';
        content_elem.innerHTML = pawnToHTML(content);

        var input_elem = getElement('dialog-input');

        input_line_elem.style.display = (style == 0) ? 'none' : 'block';
        input_elem.value = '';
        input_elem.type = (style == 1) ? 'text' : 'password';

		if(style != 0) {
			input_elem.focus();
		}

        dialog.listitem = -1;
    }
    else if(style == 2 || style == 4 || style == 5) {
        list_elem.style.display = 'inline-block';

        content_elem.style.display = 'none';
        input_line_elem.style.display = 'none';

        pushContentToList(content, (style == 5));

        selectListItem(0);

        var list_items = document.getElementsByClassName('dialog-list-item');

        for(var idx = 0; idx < list_items.length; idx++) {
            list_items[idx].ondblclick = () => {
                sendResponse(1);
            }
        }
    }

	getElement('dialog').scrollBy(0, 0);
}

function closeDialog() {
    if(typeof cef !== 'undefined') {
        cef.set_focus(0);
    }

    getElement('dialog').style.display = 'none';

    dialog = {
        id: -1,
        style: -1,
        listitem: -1
    }
}

function sendResponse(response) {
    var inputtext = getElement('dialog-input').value,
        listitem = dialog.listitem;

    if(dialog.style == 2 || dialog.style == 4 || dialog.style == 5) {
        var list_items = document.getElementsByClassName('dialog-list-item');

        inputtext = list_items[listitem].innerText;
    }

    if(typeof cef !== 'undefined') {
        cef.emit('CEF_DialogResponse', dialog.id, response, listitem, inputtext);
    }

    console.log(`dialogResponse(${dialog.id}, ${response}, ${listitem}, ${inputtext})`);

    closeDialog();
}

if(typeof cef !== 'undefined') {
    cef.on('ShowPlayerDialog', (dialogid, style, caption, content, button_1, button_2) => {
        showPlayerDialog(dialogid, style, caption, content, button_1, button_2);
        cef.set_focus(1);
    });
}