// ================================================================
//  ajaxcom.js ---- Ajax comment component
//  Copyright 2005-2006 Kawasaki Yusuke <u-suke [at] kawa.net>
//  http://www.kawa.net/works/ajax/ajaxcom/ajaxcom.html
// ================================================================

AjaxCom = function ( area, path ) {
    this.area = area;
    if ( typeof(path) == "undefined" ) {
        path = window.location.search;
		ary = path.split("=");
		path = ary[1];
		path = encodeURI(path);
        //path = path.replace( /\/\/\/*/g, "/" );     // multiple /
        //path = path.replace( /\/((index|default).(s?html?|asp|cgi|pl|php))?$/, "" );
        //path = path.replace( /^\//, "" );           // first /
        //path = path.replace( /\/$/, "" );           // last /
        if ( path == "" ) path = "/";               // root /
    }
    this.path = path;
    this.init_comment_area();
    return this;
};

AjaxCom.prototype.form_name     = 'Name: ';
AjaxCom.prototype.form_content  = 'Comment: ';
AjaxCom.prototype.form_submit   = 'POST';
AjaxCom.prototype.content_left  = '"';
AjaxCom.prototype.content_right = '"';
AjaxCom.prototype.error_name    = 'Name is empty.';
AjaxCom.prototype.error_content = 'Comment is empty.';
AjaxCom.prototype.error_post    = 'Failed to post your comment.';
AjaxCom.prototype.error_receive = 'No comments yet.';
AjaxCom.prototype.class_root    = 'ajaxcom';
AjaxCom.prototype.class_name    = 'ajaxcom_name';
AjaxCom.prototype.class_content = 'ajaxcom_content';
AjaxCom.prototype.class_submit  = 'ajaxcom_submit';
AjaxCom.prototype.class_issued  = 'ajaxcom_issued';
AjaxCom.prototype.class_notice  = 'ajaxcom_notice';

////
AjaxCom.prototype.url_receive   = './addons/com/ajaxcom-data';
AjaxCom.prototype.url_post      = './addons/com/ajaxcom.cgi';
////

AjaxCom.prototype.load = function ( arg ) {
	var path = decodeURI(this.path);
    var path = path.replace( /[^A-Za-z0-9\_\.\-]/g, "_" );
    var url = this.url_receive + "/" + path + ".txt";
    if ( arg ) url += "?" + arg;
    var req = this.get_http_request( "GET", url );
    var copythis = this;
    var loaded = 0;
    var func = function () {
        if ( req.readyState != 4 ) return;
        if ( loaded ++ ) return;
        if ( req.status == 404 ) {
            copythis.disp_message( copythis.error_receive );
        } else {
            copythis.update_comment( req, arg );
        }
    }
    req.onreadystatechange = func;
    req.send("");
}

AjaxCom.prototype.init_comment_area = function () {
    var ediv = document.getElementById( this.area );
    while ( ediv.childNodes.length ) {
        ediv.removeChild( ediv.firstChild );
    }

    var eform = document.createElement( "form" );
    var ep = document.createElement( "p" );
    var espan1 = document.createElement( "span" );
    var espan2 = document.createElement( "span" );
    var espan3 = document.createElement( "span" );
    var etext1 = document.createTextNode( this.form_name );
    var etext2 = document.createTextNode( this.form_content );
    var einput1 = document.createElement( "input" );
    var einput2 = document.createElement( "input" );
    var einput3 = document.createElement( "input" );
    var ful = document.createElement( "ul" );

    espan1.className = this.class_name;
    espan2.className = this.class_content;
    espan3.className = this.class_submit;

    einput1.type = "text";
    einput1.name = "name";
    espan1.appendChild( etext1 );
    espan1.appendChild( einput1 );
    ep.appendChild( espan1 );

    einput2.type = "text";
    einput2.name = "content";
    espan2.appendChild( etext2 );
    espan2.appendChild( einput2 );
    ep.appendChild( espan2 );

    einput3.type = "submit";
    einput3.name = "submit_btn";
    einput3.value = this.form_submit;
    espan3.appendChild( einput3 );
    ep.appendChild( espan3 );

    eform.appendChild( ep );
    eform.appendChild( ful );
    ediv.className = this.class_root;
    ediv.appendChild( eform );

    var copythis = this;
    var func = function (e,target) {
        copythis.post_content(e,target);
    };
    this.appendEvent( eform, "submit", func );
}

AjaxCom.prototype.update_comment = function ( req, opt ) {
    var text = this.get_response_text( req );
    if ( typeof(text) != "string" ) return;

    var ediv = document.getElementById( this.area );
    var eul = ediv.getElementsByTagName( "ul" );
    var ful = eul[0];

    while ( ful.childNodes.length ) {
        ful.removeChild( ful.firstChild );
    }

    var lines = text.split(/[\r\n][\r\n]*/);
    var scroll;
    for( var i=lines.length; i>=0; i-- ) {
        var aline = lines[i];
        if ( typeof(aline) != "string" ) continue;
		if ( aline.charAt(0) == "#" ) continue;
        var cols = lines[i].split("\t");
        if ( cols.length < 3 ) continue;
        var dd = new Date();
        dd.setW3CDTF( cols[0] );
        var iissued = dd.toLocaleString()

        var fli = document.createElement( "li" );
        var fspan1 = document.createElement( "span" );
        var fspan2 = document.createElement( "span" );
        var fspan3 = document.createElement( "span" );
        fspan1.className = this.class_name;
        fspan2.className = this.class_content;
        fspan3.className = this.class_issued;
        var ftext1 = document.createTextNode( cols[3] );
        var ftext2a = document.createTextNode( this.content_left );
        var ftext2b = document.createTextNode( cols[4] );
        var ftext2c = document.createTextNode( this.content_right );
        var ftext3 = document.createTextNode( iissued );

        fspan1.appendChild( ftext1 );
        fspan2.appendChild( ftext2a );
        if ( cols[4].match( /(https?:\/\/[A-Za-z0-9\/\-\_\.\#\%\,\;\+\:\=\?\&\~\@\*]*)/ )) {
            var fa2 = document.createElement( "a" );
            fa2.href = RegExp.$1;
            fa2.target = "_blank";
            fa2.rel = "nofollow"
            fa2.appendChild( ftext2b );
            fspan2.appendChild( fa2 );
        } else {
            fspan2.appendChild( ftext2b );
        }
        fspan2.appendChild( ftext2c );
        fspan3.appendChild( ftext3 );

        var fa1 = document.createElement( "a" );
        fa1.name = "com-"+cols[0];
        fli.appendChild( fa1 );

        fli.appendChild( fspan1 );
        fli.appendChild( fspan2 );
        fli.appendChild( fspan3 );
        ful.appendChild( fli );

        if ( location.hash == "#com-"+cols[0] ) {
            scroll = fli;
        }
    }
    if ( scroll && ! opt ) {
        var y = scroll.offsetTop;
        if ( y ) window.scrollTo(0,y);
    }
}

AjaxCom.prototype.disp_message = function ( content ) {
    var ediv = document.getElementById( this.area );
    var eul = ediv.getElementsByTagName( "ul" );
    var ful = eul[0];
    var dd = new Date();
    var iissued = dd.toLocaleString()

    var fli = document.createElement( "li" );
    var fspan2 = document.createElement( "span" );
    var fspan3 = document.createElement( "span" );
    fspan2.className = this.class_notice;
    fspan3.className = this.class_issued;
    var ftext2b = document.createTextNode( content );
    var ftext3 = document.createTextNode( iissued );

    fspan2.appendChild( ftext2b );
    fspan3.appendChild( ftext3 );
    fli.appendChild( fspan2 );
    fli.appendChild( fspan3 );

    if ( ful.firstChild ) {
        ful.insertBefore( fli, ful.firstChild );
    } else {
        ful.appendChild( fli );
    }
}

AjaxCom.prototype.appendEvent = function ( target, type, func ) {
    var copyfunc = func;
    if ( target.attachEvent ) {
        var iefunc = function () {
            event.returnValue = false;
            copyfunc( event, event.srcElement );
        };
        target.attachEvent( "on"+type, iefunc );
    } else {
        var domfunc = function (e) {
            e.preventDefault();
            copyfunc( e, e.target );
        };
        target.addEventListener( type, domfunc, false );
    }
}

AjaxCom.prototype.post_content = function ( e, eform ) {
    var query = {
        name:       eform.elements[0].value,
        content:    eform.elements[1].value
    };
    if ( query.name == "" ) {
        this.disp_message( this.error_name );
        return;
    }
    if ( query.content == "" ) {
        this.disp_message( this.error_content );
        return;
    }
    var body = this.hash_to_text( query );
    var url = this.url_post + "/" + this.path;
    var req = this.get_http_request( "POST", url );
    var copythis = this;
    var loaded = 0;
    var func = function () {
        if ( req.readyState != 4 ) return;
        if ( loaded ++ ) return;
        copythis.target_form.elements[2].disabled = false;
        if ( req.status != 200 ) {
            copythis.disp_message( req.status+" "+req.statusText );
            copythis.disp_message( copythis.error_post );
        } else {
            var error = copythis.get_response_value( req, "error" );
            if ( error == "0" ) {
                var arg = "t=" + Math.floor(Math.random()*9000+1000);
                copythis.load( arg );
            } else {
                var mess = copythis.get_response_value( req, "message" );
                if ( mess ) copythis.disp_message( mess );
                copythis.disp_message( copythis.error_post );
            }
        }
    }
    req.onreadystatechange = func;
    eform.elements[2].disabled = true;
    req.send(body);
    this.target_form = eform;
    eform.elements[1].value = "";
}

AjaxCom.prototype.get_http_request = function ( method, url ) {
    var req;
    if ( window.XMLHttpRequest ) {
        req = new XMLHttpRequest();
    } else if ( window.ActiveXObject ) {
        req = new ActiveXObject( "Microsoft.XMLHTTP" );
    } else {
        return;
    }
    req.open( method, url, true );
    if ( typeof(req.setRequestHeader) != "undefined" ) {
        req.setRequestHeader( "Content-Type", "application/x-www-form-urlencoded" );
    }
    return req;
}

AjaxCom.prototype.get_response_text = function ( req ) {
    var text = req.responseText;
    if ( navigator.appVersion.indexOf( "KHTML" ) > -1 ) {
        var esc = escape( text );
        esc = esc.replace( /^(%[89ABab][0-9A-Fa-f])+/, "?" );
        if ( esc.indexOf("%u") < 0 && esc.indexOf("%") > -1 ) {
            text = decodeURIComponent( esc );
        }
    }
    return text;
}

AjaxCom.prototype.get_response_value = function ( req, name ) {
    var xml = req.responseXML;
    if ( ! xml ) return "";
    var elem = xml.getElementsByTagName( name );
    if ( ! elem ) return "";
    if ( ! elem.length ) return "";
    return elem[0].firstChild.nodeValue;
}

AjaxCom.prototype.hash_to_text = function ( hash ) {
    var array = [];
    for( var key in hash ) {
        array[array.length] = key+"="+encodeURIComponent(hash[key]);
    }
    return array.join("&");
}

Date.prototype.setW3CDTF = function( dtf ) {
    var sp = dtf.split( /[^0-9]/ );
    if ( sp.length < 6 || sp.length > 8 ) return;

    if ( sp.length == 7 ) {
        if ( dtf.charAt( dtf.length-1 ) != "Z" ) return;
    }

    for( var i=0; i<sp.length; i++ ) sp[i] = sp[i]-0;    // to numeric

    if ( sp[0] < 1970 ||                // year
         sp[1] < 1 || sp[1] > 12 ||     // month
         sp[2] < 1 || sp[2] > 31 ||     // day
         sp[3] < 0 || sp[3] > 23 ||     // hour
         sp[4] < 0 || sp[4] > 59 ||     // min
         sp[5] < 0 || sp[5] > 60 ) {    // sec
        return;                         // invalid date 
    }

    // get UTC milli seconds
    var msec = Date.UTC( sp[0], sp[1]-1, sp[2], sp[3], sp[4], sp[5] );

    // time zene offset
    if ( sp.length == 8 ) {
        if ( dtf.indexOf("+") < 0 ) sp[6] *= -1;
        if ( sp[6] < -12 || sp[6] > 13 ) return;    // time zone offset hour
        if ( sp[7] < 0 || sp[7] > 59 ) return;      // time zone offset min
        msec -= (sp[6]*60+sp[7]) * 60000;
    }

    // set by milli second;
    return this.setTime( msec );
}

// ****
