/* User-authored sector names are plain text inside structured controls. */
params [["_text","",[""]]];
private _out="";
{
 _out=_out+(switch(_x)do{case 38:{"&amp;"};case 60:{"&lt;"};case 62:{"&gt;"};case 34:{"&quot;"};default{toString[_x]};});
}forEach toArray _text;
_out
