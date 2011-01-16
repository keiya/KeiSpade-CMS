function GetFile(fname, fsize){
	var div=document.getElementById("show");
	if(!div){return;}
	div.innerHTML = "Upload successfully completed.<br>"
	div.innerHTML+= "Filename: "+fname+"<br>";
	div.innerHTML+= "Filesize: "+fsize+"bytes<br>";
}

