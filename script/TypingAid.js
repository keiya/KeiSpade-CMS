/*
HTMLで
<textarea cols="30" rows="3" id="test"></textarea>
または
<input type="text" value="" size="30" id="test" />
というものがあればJavaScriptで
var aid=new TypingAid(document.getElementById("test"));
とすることでaidを通して入力欄を操作することが出来る。

class TypingAid{
  public:
    TypingAid(HTMLElement node);
    //TypingAidクラスのコンストラクタ。

    HTMLElement node;
    //インスタンスに関連付けられた要素。
    //書き換えてはいけない。

    String nodeType;
    //nodeがどのような種類の要素かを表す文字列。
    //nodeTypeが"textarea"ならnodeはtextarea要素、nodeTypeが'input[type="text"]'ならnodeはtype属性の値がtextのinput要素である。
    //書き換えてはいけない。

    String newLine();
    //改行コードと思われる文字列を返す。
    //"\r\n"、"\r"、"\n"の何れかが返ってくるが今のところ厳密な判定ではない。

    Number start();
    //選択範囲の始点を返す。
    //nodeのabcdeという文字列のうちbcdをドラッグしていると1が返り値となる。

    Number start(Number value);
    //選択範囲の始点を設定する。
    //返り値はvalueである。

    Number end();
    //選択範囲の終点を返す。
    //nodeのabcdeという文字列のうちbcdをドラッグしていると4が返り値となる。

    Number end(Number value);
    //選択範囲の終点を設定する。
    //返り値はvalueである。

    String text();
    //選択範囲の文字列を返す。

    void setSelectionRange(Number start, Number end);
    //選択範囲の始点と終点を設定する。

    void add(String str1, String str2);
    //選択範囲の直前にstr1を、直後にstr2を挿入する。
    //add実行後の選択範囲は実行前の選択範囲と等しい。

    void enclose(String str1, String str2);
    //選択範囲の直前にstr1を、直後にstr2を挿入する。
    //enclose実行後の選択範囲はstr1+実行前の選択範囲+str2である。

    void encloseLines(String str1, String str2);
    //選択範囲のうち各行について行頭にstr1を、行末にstr2を挿入する。
};

[Note]
IEはドラッグ範囲の末尾が1個以上の連続する改行である時その改行を認識出来ない。
この仕様のため、IEではabcde\r\n\r\nのbcde\r\nをドラッグしていると、
aid.end()→7のはずが5が返る
aid.text()→bcde\r\nのはずがbcdeが返る
という動作になる。
*/


function TypingAid(node){
  this.node=node;
  try{
    if(node.nodeName.toUpperCase()=="TEXTAREA") this.nodeType="textarea";
    else if(node.nodeName.toUpperCase()=="INPUT"&&node.type.toUpperCase()=="TEXT") this.nodeType='input[type="text"]';
    else throw new Error();
  }catch(e){
    throw new Error("コンストラクタの引数にはtextarea要素かtype属性の値がtextのinput要素のみとることが出来ます。");
  }
}
//各ブラウザのテキストエリアでの改行コード
//参照：http://shimax.cocolog-nifty.com/search/2006/09/post_b296.html
TypingAid.prototype.newLine=function(){
  if(this.node.value.indexOf("\r\n")>-1) return "\r\n";
  else if(this.node.value.indexOf("\n")>-1) return "\n";
  else if(this.node.value.indexOf("\r")>-1) return "\r";
  else return "\n";
};
if(/*@cc_on!@*/0){ //IE
  TypingAid.prototype.start=function(value){
    if(arguments.length){
      this.setSelectionRange(value,this.end());
      return value;
    }else{
      this.node.focus();
      var selectionRange=document.selection.createRange();
      if(this.nodeType=="textarea"){
        var range=document.body.createTextRange();
        range.moveToElementText(this.node);
      }else if(this.nodeType=='input[type="text"]'){
        var range=this.node.createTextRange();
      }
      var nodeLength=range.text.length;
      range.setEndPoint("StartToStart",selectionRange);
      return nodeLength-range.text.length;
    }
  };
  TypingAid.prototype.end=function(value){
    if(arguments.length){
      this.setSelectionRange(this.start(),value);
      return value;
    }else{
      return this.start()+this.text().length;
    }
  };
  TypingAid.prototype.text=function(){
    this.node.focus();
    return document.selection.createRange().text;
  };
  TypingAid.prototype.setSelectionRange=function(start,end){
    if(this.newLine()=="\r\n"){
      start=this.node.value.substring(0,start).replace(/\r/g,"").length;
      end=this.node.value.substring(0,end).replace(/\r/g,"").length;
    }
    this.node.focus();
    var nodeRange=this.node.createTextRange();
    nodeRange.collapse(true);
    nodeRange.moveEnd("character",end);
    nodeRange.moveStart("character",start);
    nodeRange.select();
  };
}else{ //except IE
  TypingAid.prototype.start=function(value){
    if(arguments.length){
      this.node.focus();
      this.node.selectionStart=value;
      return value;
    }else{
      this.node.focus();
      return this.node.selectionStart;
    }
  };
  TypingAid.prototype.end=function(value){
    if(arguments.length){
      this.node.focus();
      this.node.selectionEnd=value;
      return value;
    }else{
      this.node.focus();
      return this.node.selectionEnd;
    }
  };
  TypingAid.prototype.text=function(){
    return this.node.value.substring(this.start(),this.end());
  };
  TypingAid.prototype.setSelectionRange=function(start,end){
    this.node.focus();
    this.node.setSelectionRange(start,end);
  };
}
TypingAid.prototype.enclose=function(str1,str2){
  var start=this.start();
  var end=this.end();
  this.node.value=this.node.value.substring(0,start)+str1+this.text()+str2+this.node.value.substring(end,this.node.value.length);
  this.setSelectionRange(start,end+str1.length+str2.length);
};
TypingAid.prototype.add=function(str1,str2){
  var start=this.start();
  var end=this.end();
  this.node.value=this.node.value.substring(0,start)+str1+this.text()+str2+this.node.value.substring(end,this.node.value.length);
  this.setSelectionRange(start+str1.length,end+str1.length);
};
TypingAid.prototype.encloseLines=function(str1,str2){
  var start=this.start();
  var end=this.end();
  var newLine=this.newLine();
  var lines=this.text().split(newLine);
  if(lines.length>1&&lines[lines.length-1]=="") lines.pop();
  var result=[];
  for(var i=0,len=lines.length;i<len;i++){
    result.push(str1+lines[i]+str2);
  }
  result=result.join(newLine);
  this.node.value=this.node.value.substring(0,start)+result+this.node.value.substring(end,this.node.value.length);
  this.setSelectionRange(start,end+result.length);
};
