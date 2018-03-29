/*
  ----------------------------------------------------------------------
  Filename:  Acrfn.g
  ----------------------------------------------------------------------
  AMENDMENT HISTORY

     Issue  |  Date
     -----  |  ----
      1.0   | 11/28/16  Borislav Ankov, Filter fix

  ----------------------------------------------------------------------
*/
{
import fsp2.normalisation.Normaliser;
import fsp2.normalisation.text.StoryBlock;
}
class AcrfnLexer extends Lexer;
options {
   k=3;
   exportVocab=Acrfnvocab;
   charVocabulary = '\u0000'..'\uFFFE';
   caseSensitive=false;
   caseSensitiveLiterals = false;
}
tokens { EUNKNOWN; }
{
private Normaliser norm;
public AcrfnLexer(Reader in, Normaliser normalise)
{
   this(new CharBuffer(in));
   setTokenObjectClass("AttrToken");
}
}
/* SGML definitions based on:
http://xml.coverpages.org/sgmlsyn/contents.htm
http://www.oasis-open.org/cover/sgmlprodAgnew.html
And XML definition:
http://www.xml.dvint.com/ebnf/
*/

/* Define newline so Antlr can count lines in the data */
protected
NL
   : ( options {generateAmbigWarnings=false;}
     :  "\r\n" | '\r' | '\n'
     )
   {newline();}
;
// optional space/tab/cr/lf
protected
O_SP :  ( options {greedy=true;}: SP)?
;
// mimimum_literal. Also system_identifier
protected
STRING
   :  '"' (~'"')* '"'
   |  '\'' (~'\'')* '\''
   ;
protected
DIGIT
   :  '0'..'9'
   ;
protected
EQ
   : (SP)? '=' (SP)?
;
//protected
//ATTR_VALUE :
//      '"'! (~('>'|'"'))* '"'!
//    | "'"! (~('>'|'\''))* "'"!
//    | ('a'..'z'|'0'..'9')+
//    | "#default"
//;
protected
ATTR_VALUE :
      '"'! (~('>'|'"'))* '"'!
    | "'"! (~('>'|'\''))* "'"!
    | '\u201c'! (~('>'|'\u201c'|'\u201d'))* '\u201d'!
    | (options {greedy=true;}: 'a'..'z'|'0'..'9'|'#'|'+'|'-'|'.'|'_'|':')+
;
protected
SGML_LETTER :
   'a'..'z'
;
protected
SGML_SPECIAL :
  '\''|'('|')'|'+'|'-'|'.'|'/'|':'|'='|'?'
;
protected
SGML_NAMECHAR : // name_character
   ( SGML_LETTER | DIGIT | '.' | '-' | '_' | ':' )
;
protected
SGML_NAME : // name
   (SGML_LETTER | '_' | ':' ) (options {greedy=true;}: SGML_NAMECHAR)*
;
protected
  ATTR_NAME :
	(options {greedy=true;}: 'a'..'z'|'0'..'9'|'#'|'+'|'-'|'.'|'_'|':')+
 ;
/*
Generic pattern for matching against
document_type_declaration and link_type_declaration
*/
protected
TYPE_DECLARATION :
    (PS)+ (TYPE_DEFINITION_LIST)+ '>'
;
/*
Generic pattern for matching against definition lists
such as ATTLIST ELEMENT ENTITY etc
*/
protected
TYPE_DEFINITION_LIST :
   (
    '[' (SET_DECLARATION)* ']'
   | (options {greedy=true;}: ~('['|'<'|'>'|'\t'|'\n'|'\r'|' '|'%'))+
   )
   (PS)*
;
/*
Generic pattern for matching against sets such as entity_set, element_set etc
*/
protected
SET_DECLARATION :
    "<!" (SGML_LETTER)+ (PS)+ (DEFINITION_LIST)+ '>'
   | SP
   | PARAMETER_ENTITY_REFERENCE
   | COMMENT
   | PROCESSING_INSTRUCTION
   //| MARKED_SECTION
;
/*
Generic pattern for matching against definition lists
such as ATTLIST ELEMENT ENTITY etc
*/
protected
DEFINITION_LIST :
   (
    NAME_GROUP
//   | PARAMETER_ENTITY_NAME
   | '[' (~']')* ']'
   | (options {greedy=true;}: ~('['|'<'|'>'|'('|'\t'|'\n'|'\r'|' '|'%'))+
   )
   (PS)*
;
// parameter_entity_reference
protected
PARAMETER_ENTITY_REFERENCE :
   '%' (O_NAME_GROUP|(SP)+) SGML_NAME (options {greedy=true;}: ';')?
;
// parameter_entity_name
protected
PARAMETER_ENTITY_NAME :
   '%' (PS)+ SGML_NAME
;
// parameter separator
protected
PS :
     SP
   | PARAMETER_ENTITY_REFERENCE
   | COMMENT
;
// optional parameter separator
protected
O_PS : ( options {greedy=true;}: PS)?
;
// declaration separator
protected
DS :
     SP
   | PARAMETER_ENTITY_REFERENCE
   | COMMENT
   | PROCESSING_INSTRUCTION
  // | MARKED_SECTION
;
protected
NAME_GROUP :
    '(' (~')')* ')'
;
// optional name group
// also called document_type_specification
protected
O_NAME_GROUP :
   (NAME_GROUP)?
;
// Unprotected tokens visible to the Parser

SP : ( options {generateAmbigWarnings=false;}:
     NL
   | ' '
   | '\t'
   )+
;
EMPTY_TAG :
   "<>"
;
TAG : // start_tag
   "<" O_NAME_GROUP! SGML_NAME
   {
      String sgmlName = $getText;
      AttrToken t = new AttrToken( TAG, sgmlName+">" );
      int tagType = testLiteralsTable(t.getText(),0);
      if( tagType != 0 ) _ttype = tagType;
   }
   O_SP		// Added 20050817
	//   (SP (name:SGML_NAME EQ attr:ATTR_VALUE (SP)? {t.add(name.getText(),attr.getText());})*)?
   (options {greedy=true;}:
       name:ATTR_NAME O_SP ( options {greedy=true;}: EQ attr:ATTR_VALUE O_SP)?
       {
          if(attr==null)
            t.add(name.getText(),name.getText());
          else
            t.add(name.getText(),attr.getText());
       }
   )* 		// Remove on 20050817 (SP)?
   ('/'
      {
         tagType = testLiteralsTable(sgmlName+"/>",0);
         if( tagType == 0 )
         {
            $setType(EMPTY_TAG);
            t=null;
         }
         else
         {
            t.setText(sgmlName+"/>");
            _ttype = tagType;
         }
     }
   )?
   (">")?
   {
      if( t != null )
      {
         t.setType(_ttype);
         $setToken(t);
      }
   }
   ;
END_TAG :
     "</>"
   | "</" O_NAME_GROUP! SGML_NAME ">"
;
/* There is an ambiguity in the definition of SGML in that SP can appear as rubbish
after a tag or as data. In order to expose SP to the Parser the first character of
PCDATA cannot be a white space and we should check for SP before PCDATA in the Parser.
*/
PCDATA :
   ~('\n'|'\r'|' '|'\t')
   (
     options {greedy=true;}: // to avoid conflict with COMMENT in SGML_DECLARATION
       NL
     | ~('<'|'\n'|'\r')
   )*
;
COMMENT :  // "<!>" or "<!--" anything until "-->"
     "<!>" !
   | "<!--" !
     ( options {greedy=true;}:
       {!(LA(2)=='-' && LA(3)=='>')}? '-'
       | NL
       |  ~('-'|'\n'|'\r')
     )+
     "-->"! O_SP
;
O_CDATA : "<![cdata["
;
C_CDATA : "]]>"
;
DOT_DATA : "<...>"
;
C_PRN : ">"
;
/*MARKED_SECTION : // "<![" anything until "]]>"
   "<![" !
   ( options {greedy=true;}:
     {!(LA(2)==']' && LA(3)=='>')}? ']'
     | NL
     | ~(']'|'\n'|'\r')
   )*
   "]]>" !
;*/
PROCESSING_INSTRUCTION : // "<?" anything until ">"
   "<?"! (~'>')* '>'!
;
SGML_DECLARATION :
   "<!sgml" (COMMENT | PCDATA)+ '>'
;
/*
short reference use declaration - "<!usemap" anything until ">"
link set use declaration - "<!uselink" anything until ">"
*/
SGML_USE :
   "<!u" (~'>')* '>'
;
// link_type_declaration
LINK_TYPE :
   "<!linktype" (PS)+ (TYPE_DEFINITION_LIST)+ '>'
;
SGML_DOCTYPE    : "<!doctype"! (PS)+ (TYPE_DEFINITION_LIST)+ '>'
;

//////////////////////////////////////////////////////////////////////////
{
import fsp2.normalisation.Normaliser;
import fsp2.normalisation.text.StoryBlock;
import fsp2.normalisation.objects.*;
import fsp2.normalisation.text.*;
import java.util.*;
import java.text.*;
import java.util.regex.Matcher;
import java.util.regex.Pattern;
import fsp2.normalisation.accession.Accession;
import fsp2.normalisation.config.Action;
import fsp2.common.DateTime;
import java.sql.Date;
import fsp2.normalisation.PubDate;
import fsp2.normalisation.text.SubjectList;

}
class AcrfnParser extends Parser;
options {
// k=1;
// importVocab=XMLvocab;
// testLiterals = false;
}
tokens
{
	O_ACTION = "<action>";
	C_ACTION = "</action>";
	E_ACTION = "<action/>";

	O_PUBDATE	= "<date>";
	C_PUBDATE	= "</date>";
	E_PUBDATE	= "<date/>";

	O_PUBTIME	= "<time>";
	C_PUBTIME	= "</time>";
	E_PUBTIME	= "<time/>";

	O_SECTION	= "<category>";
	C_SECTION	= "</category>";
	E_SECTION	= "<category/>";

	O_HEADLINE	= "<title>";
	C_HEADLINE	= "</title>";
	E_HEADLINE	= "<title/>";

	O_STORY_START	= "<item>";
	C_STORY_START	= "</item>";
	E_STORY_START	= "<item/>";

	O_STORYTEXT	= "<content>";
	C_STORYTEXT	= "</content>";
	E_STORYTEXT	= "<content/>";

	O_ID = "<nsid>";
	C_ID = "</nsid>";
	E_ID = "<nsid/>";

  	O_IMG = "<img>";
	C_IMG = "</img>";
	E_IMG = "<img/>";

  	O_IMAGE = "<image>";
  	C_IMAGE = "</image>";
  	E_IMAGE = "<image/>";

    O_URL = "<url>";
    C_URL = "</url>";
    E_URL = "<url/>";

	//O_PARAGRAPH0	= "<P>";
	//C_PARAGRAPH0	= "</P>";
	//E_PARAGRAPH0	= "<P/>";

	O_PARAGRAPH1	= "<p>";
	C_PARAGRAPH1	= "</p>";
	E_PARAGRAPH1	= "<p/>";

	O_PARAGRAPH2	= "<br>";
	C_PARAGRAPH2	= "</br>";
	E_PARAGRAPH2	= "<br/>";

	O_PARAGRAPH3	= "<BR>";
	C_PARAGRAPH3	= "</BR>";
	E_PARAGRAPH3	= "<BR/>";

	O_H1	= "<h1>";
	C_H1	= "</h1>";
	E_H1	= "<h1/>";
	O_H2	= "<h2>";
	C_H2	= "</h2>";
	E_H2	= "<h2/>";
	O_H3	= "<h3>";
	C_H3	= "</h3>";
	E_H3	= "<h3/>";
	O_H4	= "<h4>";
	C_H4	= "</h4>";
	E_H4	= "<h4/>";
	O_H5	= "<h5>";
	C_H5	= "</h5>";
	E_H5	= "<h5/>";
	O_H6	= "<h6>";
	C_H6	= "</h6>";
	E_H6	= "<h6/>";

	O_DIV	= "<div>";
	C_DIV	= "</div>";
	E_DIV	= "<div/>";

	O_STRONG="<strong>";
	C_STRONG="</strong>";
	E_STRONG="<strong/>";

	O_LI="<li>";
	C_LI="</li>";
	E_LI="<li/>";

	O_UL="<ul>";
	C_UL="</ul>";
	E_UL="<ul/>";

	O_OL="<ol>";
	C_OL="</ol>";
	E_OL="<ol/>";

	O_ANCHOR="<a>";
	C_ANCHOR="</a>";
	E_ANCHOR="<a/>";

	O_EM="<em>";
	C_EM="</em>";
	E_EM="<em/>";

	O_I="<i>";
	C_I="</i>";
	E_I="<i/>";

	O_B="<b>";
	C_B="</b>";
	E_B="<b/>";

	O_U="<u>";
	C_U="</u>";
	E_U="<u/>";

	O_FONT="<font>";
	C_FONT="</font>";
	E_FONT="<font/>";

	O_SUP="<sup>";
	C_SUP="</sup>";
	E_SUP="<sup/>";

	O_SUB="<sub>";
	C_SUB="</sub>";
	E_SUB="<sub/>";

	O_BLOCK="<block>";
	C_BLOCK="</block>";
	E_BLOCK="<block/>";

	O_BG="<bg>";
	C_BG="</bg>";
	E_BG="<bg/>";

	O_BQ="<blockquote>";
	C_BQ="</blockquote>";
	E_BQ="<blockquote/>";

	O_SPAN="<span>";
	C_SPAN="</span>";
	E_SPAN="<span/>";

	O_HR="<hr>";
	C_HR="</hr>";
	E_HR="<hr/>";

}
{
private Normaliser norm;
private boolean storyStartFlag=false;
private String getID = "";
private String sLookup = "";
private String sAdd = "";

public AcrfnParser(TokenStream lexer, Normaliser normalise)
{
  this(lexer,2);
  norm = normalise;


  //norm.getFSPIO().println("New ID 2:" + sLookup);


}
    public void reportError(RecognitionException ex)
    {
        norm.getFSPIO().println(ex.toString());
        norm.toHoldQueue( 108, "Invalid format" );
    }
    public void reportError(ANTLRException ex)
    {
        norm.getFSPIO().println(ex.toString());
        norm.toHoldQueue( 108, "Invalid format" );
    }


	public String  replaceTags(String content){

		String fileContent=content;
		String pat[] = { "<br ","<w:LsdException ","<TABLE ", "<TR ", "<TD ","<TBODY ","<P ","<font ","<table ","<td ","<tr ","<li ","<ul ","<!--","<TH ","<p ","<th ","<span ","<div ","<input ","<form ","<object ","<param ","<strong ","<em ","<ol ","<b ","<sub ","<blockquote ","<b ","<hr ","<col ","<colgroup ","<!","<script ","<iframe ","<h1 ","<h2 ","<h3 ","<h4 ","<h5 ","<h6 ","<H1 ","<H2 ","<H3 ","<H4 ","<H5 ","<H6 "};
		// corresponding new value
		String mat[] = { "<br />","","<table>", "<tr>", "<td>","<tbody>","<P>","","<table>","<td>","<tr>","<li>","<ul>","","<th>","<p>","<td>","<span>","<div>","<input>","<form>","","","<strong>","","","","","","<b>","<hr>","<col>","<colgroup>","","<script>","<iframe>","<h1>","<h2>","<h3>","<h4>","<h5>","<h6>","<H1>","<H2>","<H3>","<H4>","<H5>","<H6>"};
		fileContent=fileContent.replaceAll("&amp;","&");
		fileContent=fileContent.replaceAll("&lt;style&gt;","");
		fileContent=fileContent.replaceAll("&lt;/style&gt;","");
		fileContent=fileContent.replaceAll("&lt;","<");
		fileContent=fileContent.replaceAll("&gt;",">");
		fileContent=fileContent.replaceAll("&amp;","&");
		fileContent=fileContent.replaceAll("&quot;","\"");
		fileContent=fileContent.replaceAll("&nbsp;"," ");
		fileContent=fileContent.replaceAll("nbsp;"," ");
		fileContent=fileContent.replaceAll("&#34;","\"");
		fileContent=fileContent.replaceAll("&#39;","\'");
		fileContent=fileContent.replaceAll("&#150;","-");
		fileContent=fileContent.replaceAll("&#149;",".");
		fileContent=fileContent.replaceAll("&#148;","\"");
		fileContent=fileContent.replaceAll("&#147;","\"");
		fileContent=fileContent.replaceAll("&#146;","\'");
		fileContent=fileContent.replaceAll("&#145;","\'");
		fileContent=fileContent.replaceAll("&#63;","?");
		fileContent=fileContent.replaceAll("&#64;","@");
		fileContent=fileContent.replaceAll("&#129;","\u0081");
		fileContent=fileContent.replaceAll("&#157;","\u009D");
		fileContent=fileContent.replaceAll("<P>","<p>");
		fileContent=fileContent.replaceAll("</P>","</p>");

		fileContent=fileContent.replaceAll("&nbsp;&nbsp;"," ");
		fileContent=fileContent.replaceAll("&amp;nbsp;"," ");
		for (int i = 0; i < pat.length; i++)
			fileContent = replaceTag(fileContent, pat[i], mat[i]);

// ???
      //for(int i : pat[]){
      // fileContent = replaceTag(fileContent, pat[i], mat[i];)
    // }

		//handling html elements
		fileContent=fileContent.replaceAll("<TBODY>","");
		fileContent=fileContent.replaceAll("</TBODY>","");
		fileContent=fileContent.replaceAll("</TABLE>","</table>");
		fileContent=fileContent.replaceAll("<TABLE>","<table>");
		fileContent=fileContent.replaceAll("<TR>","<tr>");
		fileContent=fileContent.replaceAll("</TR>","</tr>");
		fileContent=fileContent.replaceAll("<TD>","<td>");
		fileContent=fileContent.replaceAll("</TD>","</td>");
		fileContent=fileContent.replaceAll("</TH>","</th>");
		fileContent=fileContent.replaceAll("<TH>","<td>");
		fileContent=fileContent.replaceAll("<th>","<td>");

		fileContent=fileContent.replaceAll("<hr />","<hr>");
		fileContent=fileContent.replaceAll("<A ", "<a ");
		fileContent=fileContent.replaceAll("</A>", "</a>");
		fileContent=fileContent.replaceAll("<b>","");
		fileContent=fileContent.replaceAll("</b>","");
		fileContent=fileContent.replaceAll("<B>","");
		fileContent=fileContent.replaceAll("</B>","");
		fileContent=fileContent.replaceAll("<STRONG>","");
		fileContent=fileContent.replaceAll("</STRONG>","");
		fileContent=fileContent.replaceAll("<bold>","");
		fileContent=fileContent.replaceAll("</bold>","");
		fileContent=fileContent.replaceAll("<I>","");
		fileContent=fileContent.replaceAll("</I>","");
		fileContent=fileContent.replaceAll("<i>","");
		fileContent=fileContent.replaceAll("</i>","");
		fileContent=fileContent.replaceAll("<italic>","");
		fileContent=fileContent.replaceAll("</italic>","");
		fileContent=fileContent.replaceAll("<u>","");
		fileContent=fileContent.replaceAll("</u>","");
		fileContent=fileContent.replaceAll("<input>","");
		fileContent=fileContent.replaceAll("<font>","");
		fileContent=fileContent.replaceAll("</font>","");
		fileContent=fileContent.replaceAll("<EM>","");
		fileContent=fileContent.replaceAll("</EM>","");
		fileContent=fileContent.replaceAll("<em>","");
		fileContent=fileContent.replaceAll("</em>","");
		//fileContent=fileContent.replaceAll("<img>","");
		//fileContent=fileContent.replaceAll("</img>","");
		//fileContent=fileContent.replaceAll("<IMG>","");
		//fileContent=fileContent.replaceAll("</IMG>","");
		fileContent=fileContent.replaceAll("<span>","");
		fileContent=fileContent.replaceAll("</span>","");
		fileContent=fileContent.replaceAll("<strong>","");
		fileContent=fileContent.replaceAll("</strong>","");
		fileContent=fileContent.replaceAll("<html>","");
		fileContent=fileContent.replaceAll("</html>","");
		fileContent=fileContent.replaceAll("<meta>","");
		fileContent=fileContent.replaceAll("</meta>","");
		fileContent=fileContent.replaceAll("<ul>","");
		fileContent=fileContent.replaceAll("</ul>","");
		fileContent=fileContent.replaceAll("<ol>","");
		fileContent=fileContent.replaceAll("</ol>","");
		fileContent=fileContent.replaceAll("<sup>","");
		fileContent=fileContent.replaceAll("</sup>","");
		fileContent=fileContent.replaceAll("<block>","");
		fileContent=fileContent.replaceAll("</block>","");
		fileContent=fileContent.replaceAll("<blockquote>","");
		fileContent=fileContent.replaceAll("</blockquote>","");
		fileContent=fileContent.replaceAll("<cite>","");
		fileContent=fileContent.replaceAll("</cite>","");
		fileContent=fileContent.replaceAll("<div>","");
		fileContent=fileContent.replaceAll("</div>","");
		fileContent=fileContent.replaceAll("<object>","");
		// fileContent=fileContent.replaceAll("</embed>","");
		//fileContent=fileContent.replaceAll("<embed>","");
		fileContent=fileContent.replaceAll("</object>","");
		fileContent=fileContent.replaceAll("<param>","");
		fileContent=fileContent.replaceAll("</param>","");
		fileContent=fileContent.replaceAll("<thead>","");
		fileContent=fileContent.replaceAll("</thead>","");
		//fileContent=fileContent.replaceAll("</iframe>","");
		//fileContent=fileContent.replaceAll("<iframe>","");
		fileContent=fileContent.replaceAll("</sub>","");
		fileContent=fileContent.replaceAll("<sub>","");
		fileContent=fileContent.replaceAll("</small>","");
		fileContent=fileContent.replaceAll("<small>","");
		fileContent=fileContent.replaceAll("</col>","");
		fileContent=fileContent.replaceAll("<col>","");
		fileContent=fileContent.replaceAll("</colgroup>","");
		fileContent=fileContent.replaceAll("<colgroup>","");
		fileContent=fileContent.replaceAll("</center>","");
		fileContent=fileContent.replaceAll("<center>","");
		fileContent=fileContent.replace("<br title=\"pagebreak\" />","");
		fileContent=fileContent.replace("<br clear=\"none\"/>","");
		fileContent=fileContent.replace("<br /><br />","<br>");
		fileContent=fileContent.replace("<br />","<br>");
		//<br/><br/>
		fileContent=fileContent.replaceAll("<h6>",StoryBlock.PARA_STR);
		fileContent=fileContent.replaceAll("</h6>",StoryBlock.PARA_STR);
		fileContent=fileContent.replaceAll("<h5>",StoryBlock.PARA_STR);
		fileContent=fileContent.replaceAll("</h5>",StoryBlock.PARA_STR);
		fileContent=fileContent.replaceAll("<h4>",StoryBlock.PARA_STR);
		fileContent=fileContent.replaceAll("</h4>",StoryBlock.PARA_STR);
		fileContent=fileContent.replaceAll("<h3>",StoryBlock.PARA_STR);
		fileContent=fileContent.replaceAll("</h3>",StoryBlock.PARA_STR);
		fileContent=fileContent.replaceAll("<h2>",StoryBlock.PARA_STR);
		fileContent=fileContent.replaceAll("</h2>",StoryBlock.PARA_STR);
		fileContent=fileContent.replaceAll("<h1>",StoryBlock.PARA_STR);
		fileContent=fileContent.replaceAll("</h1>",StoryBlock.PARA_STR);
		fileContent=fileContent.replaceAll("<H6>",StoryBlock.PARA_STR);
		fileContent=fileContent.replaceAll("</H6>",StoryBlock.PARA_STR);
		fileContent=fileContent.replaceAll("<H5>",StoryBlock.PARA_STR);
		fileContent=fileContent.replaceAll("</H5>",StoryBlock.PARA_STR);
		fileContent=fileContent.replaceAll("<H4>",StoryBlock.PARA_STR);
		fileContent=fileContent.replaceAll("</H4>",StoryBlock.PARA_STR);
		fileContent=fileContent.replaceAll("<H3>",StoryBlock.PARA_STR);
		fileContent=fileContent.replaceAll("</H3>",StoryBlock.PARA_STR);
		fileContent=fileContent.replaceAll("<H2>",StoryBlock.PARA_STR);
		fileContent=fileContent.replaceAll("</H2>",StoryBlock.PARA_STR);
		fileContent=fileContent.replaceAll("<H1>",StoryBlock.PARA_STR);
		fileContent=fileContent.replaceAll("</H1>",StoryBlock.PARA_STR);
		fileContent=fileContent.replaceAll("<thead>","");
		fileContent=fileContent.replaceAll("</thead>","");
		fileContent=fileContent.replace("<BR />","<br>");
		fileContent=fileContent.replace("<link>","");
		fileContent=fileContent.replaceAll("<br>", StoryBlock.PARA_STR);
		// Removing iframe and nested tag
		int begin3 = 0;
		int end3 = 0;
		String s3 = fileContent;
		begin3 = s3.indexOf("<iframe>", begin3);
		while (begin3 != -1) {
			begin3 = begin3 + "<iframe>".length();
			end3 = s3.indexOf("</iframe>", begin3);
			if((begin3>-1) && (end3>-1)){

				s3 = s3.substring(0,begin3)+s3.substring(end3,s3.length());
				end3 = end3 + "</iframe>".length();
				begin3 = end3;
				begin3 = s3.indexOf("<iframe>", begin3);
			}
			else if(end3 == -1)
			{
				begin3 = end3;
			}
		}
		//norm.getFSPIO().println(s3);
		fileContent=s3;
		//s2 = s2.replaceAll("<iframe>","");
		//norm.getFSPIO().println(s2);
		fileContent=fileContent.replaceAll("<iframe>","");
		fileContent=fileContent.replaceAll("</iframe>","");
		//end of iframe removal
		fileContent=replacement(fileContent);
		return fileContent;

	}

	public  String replaceTag(String output, String pat, String mat) {
		String begin = pat;
		String end = ">";
		char[] ch = begin.toCharArray();
		String str1 = "";
		String str2 = "";

//length + () ???
		for (int temp7 = 0; temp7 < ch.length; temp7++) {
			str1 = str1 + "[" + String.valueOf(ch[temp7]) + "]";
		}

		char[] ch1 = end.toCharArray();
		for (int temp8 = 0; temp8 < ch1.length; temp8++) {
			str2 = str2 + "[" + String.valueOf(ch1[temp8]) + "]";
		}

		String patternStr = str1 + "[a-z0-9A-Z\\s\\S&&[^>]]{0,}" + str2
				+ "{0,}";

		Pattern pattern = Pattern.compile(patternStr, Pattern.UNICODE_CASE);
		String inputStr = output;
		Matcher matcher = pattern.matcher(inputStr);
		boolean matchFound = matcher.find();
		String match;

		while (matchFound) {

			match = matcher.group();

			inputStr = inputStr.replace(match, mat);
			matchFound = matcher.find();
		}
		return inputStr;
	}

	public  String createElink(String link ){

		String [] value1=link.split("jfx@23582");
		String eStr="";
		String anchor="";
		String href="";
		String content="";
		if(value1.length==2){
			href=value1[0];
			content=value1[1];
		}

		if(href!=null && href.trim().length()>0 &&(href.trim().startsWith("https")||href.trim().startsWith("http")||href.trim().startsWith("mailto:"))&&!(content.trim().startsWith("_www.")||content.trim().startsWith("_http:")))
		{
			String startEL = StoryBlock.ELINK_START + "<ELink type="+"\""+"webpage"+"\""+" ref="+"\"";
			href=href.trim();
			String middle1EL = href + "\""+">" +StoryBlock.ELINK_END;
			String middle2EL = content + StoryBlock.ELINK_START;
			String endEL = "</ELink>" + StoryBlock.ELINK_END;
			eStr=startEL+middle1EL+middle2EL+endEL;
			eStr=eStr.replaceAll(StoryBlock.PARA_STR,"");
			anchor=eStr;
		}
		else{
			anchor=content;

		}

		return anchor;
	}

	private String replacement(String text1){
		text1=text1.replaceAll("&nbsp;"," ");
		text1=text1.replaceAll("&NBSP;"," ");
		text1=text1.replaceAll("&amp;amp;", "&amp;");
		text1=text1.replaceAll("&amp;", "&");
		text1=text1.replaceAll("&gt;&gt;"," ");
		text1=text1.replaceAll("&lt;","<");
		text1=text1.replaceAll("&gt;",">");
		text1=text1.replaceAll("&nbsp;&nbsp;"," ");
		text1=text1.replaceAll("&amp;nbsp;"," ");
		text1=text1.replaceAll("<p>&#160;</p>","");
		String str=StoryBlock.PARA_STR+"* ";
		text1=text1.replaceAll("<li>",str);
		text1=text1.replaceAll("</li>",StoryBlock.PARA_STR);
		text1=text1.replaceAll("<br>      &#160;     <br>","");
		text1=text1.replaceAll("<br> &#160; <br>","");
		text1=text1.replaceAll("<br>  &#160;<br>","");
		text1=text1.replaceAll("<br> &#160;<br>","");
		text1=text1.replaceAll("<br>  &#160;<br>","");
		text1=text1.replaceAll("<br> <br>","");
		text1=text1.replaceAll("<br> <br>","");
		text1=text1.replaceAll("<br/>",StoryBlock.PARA_STR);
		text1=text1.replaceAll("<br />",StoryBlock.PARA_STR);
		text1=text1.replaceAll("<br/><br/>",StoryBlock.PARA_STR);
		text1=text1.replaceAll("<br /><br />",StoryBlock.PARA_STR);
		text1=text1.replaceAll("<BR clear=\"none\"/>",StoryBlock.PARA_STR);
		text1=text1.replaceAll("<br/>",StoryBlock.PARA_STR);
		text1=text1.replaceAll("<br>",StoryBlock.PARA_STR);
		text1=text1.replaceAll("<BR>",StoryBlock.PARA_STR);
		text1=text1.replaceAll("<p>",StoryBlock.PARA_STR);
		text1=text1.replaceAll("</p>","");
		text1=text1.replaceAll("<p/>",StoryBlock.PARA_STR);
		text1=text1.replaceAll("<BR/>",StoryBlock.PARA_STR);
		text1=text1.replaceAll("<h1>",StoryBlock.PARA_STR);
		text1=text1.replaceAll("</h1>",StoryBlock.PARA_STR);
		text1=text1.replaceAll("<h2>",StoryBlock.PARA_STR);
		text1=text1.replaceAll("</h2>",StoryBlock.PARA_STR);
		text1=text1.replaceAll("<h3>",StoryBlock.PARA_STR);
		text1=text1.replaceAll("</h3>",StoryBlock.PARA_STR);
		text1=text1.replaceAll("<h4>",StoryBlock.PARA_STR);
		text1=text1.replaceAll("</h4>",StoryBlock.PARA_STR);
		text1=text1.replaceAll("<h5>",StoryBlock.PARA_STR);
		text1=text1.replaceAll("</h5>",StoryBlock.PARA_STR);
		text1=text1.replaceAll("<h6>",StoryBlock.PARA_STR);
		text1=text1.replaceAll("</h6>",StoryBlock.PARA_STR);
		text1=text1.replaceAll("<h3>",StoryBlock.PARA_STR);
		text1=text1.replaceAll("</h3>",StoryBlock.PARA_STR);
		text1=text1.replaceAll("<hr>",StoryBlock.PARA_STR);
		text1=text1.replaceAll("</hr>",StoryBlock.PARA_STR);
		text1=text1.replaceAll("<H1>",StoryBlock.PARA_STR);
		text1=text1.replaceAll("</H1>",StoryBlock.PARA_STR);
		text1=text1.replaceAll("<H2>",StoryBlock.PARA_STR);
		text1=text1.replaceAll("</H2>",StoryBlock.PARA_STR);
		text1=text1.replaceAll("<H3>",StoryBlock.PARA_STR);
		text1=text1.replaceAll("</H3>",StoryBlock.PARA_STR);
		text1=text1.replaceAll("<H4>",StoryBlock.PARA_STR);
		text1=text1.replaceAll("</H4>",StoryBlock.PARA_STR);
		text1=text1.replaceAll("<H5>",StoryBlock.PARA_STR);
		text1=text1.replaceAll("</H5>",StoryBlock.PARA_STR);
		text1=text1.replaceAll("<H6>",StoryBlock.PARA_STR);
		text1=text1.replaceAll("</H6>",StoryBlock.PARA_STR);
		text1=text1.replaceAll("<H3>",StoryBlock.PARA_STR);
		text1=text1.replaceAll("</H3>",StoryBlock.PARA_STR);
		text1=text1.replaceAll("<HR>",StoryBlock.PARA_STR);
		text1=text1.replaceAll("</HR>",StoryBlock.PARA_STR);
		text1=text1.replaceAll("&#233;","\u00E9");
		text1=text1.replaceAll("&eacute;","\u00E9");
		text1=text1.replaceAll("&#8221;","\"");
		text1=text1.replaceAll("&#191;","\u00BF");
		text1=text1.replaceAll("&iquest;","\u00BF");
		text1=text1.replaceAll("&#192;","\u00C0");
		text1=text1.replaceAll("&Agrave;","\u00C0");
		text1=text1.replaceAll("&#193;","\u00C1");
		text1=text1.replaceAll("&Aacute;","\u00C1");
		text1=text1.replaceAll("&#194;","\u00C2");
		text1=text1.replaceAll("&Acirc;","\u00C2");
		text1=text1.replaceAll("&#195;","\u00C3");
		text1=text1.replaceAll("&Atilde;","\u00C3");
		text1=text1.replaceAll("&#200;","\u00C8");
		text1=text1.replaceAll("&Egrave;","\u00C8");
		text1=text1.replaceAll("&#201;","\u00C9");
		text1=text1.replaceAll("&Eacute;","\u00C9");
		text1=text1.replaceAll("&#202;","\u00CA");
		text1=text1.replaceAll("&Ecirc;","\u00CA");
		text1=text1.replaceAll("&#203;","\u00CB");
		text1=text1.replaceAll("&Euml;","\u00CB");
		text1=text1.replaceAll("&#204;","\u00CC");
		text1=text1.replaceAll("&Igrave;","\u00CC");
		text1=text1.replaceAll("&#205;","\u00CD");
		text1=text1.replaceAll("&Iacute;","\u00CD");
		text1=text1.replaceAll("&#206;","\u00CE");
		text1=text1.replaceAll("&Icirc;","\u00CE");
		text1=text1.replaceAll("&#207;","\u00CF");
		text1=text1.replaceAll("&Iuml;","\u00CF");
		text1=text1.replaceAll("&#209;","\u00D1");
		text1=text1.replaceAll("&Ntilde;","\u00D1");
		text1=text1.replaceAll("&#210;","\u00D2");
		text1=text1.replaceAll("&Ograve;","\u00D2");
		text1=text1.replaceAll("&#211;","\u00D3");
		text1=text1.replaceAll("&Oacute;","\u00D3");
		text1=text1.replaceAll("&#212;","\u00D4");
		text1=text1.replaceAll("&Ocirc;","\u00D4");
		text1=text1.replaceAll("&#213;","\u00D5");
		text1=text1.replaceAll("&Otilde;","\u00D5");
		text1=text1.replaceAll("&#214;","\u00D6");
		text1=text1.replaceAll("&Ouml;","\u00D6");
		text1=text1.replaceAll("&#217;","\u00D9");
		text1=text1.replaceAll("&Ugrave;","\u00D9");
		text1=text1.replaceAll("&#218;","\u00DA");
		text1=text1.replaceAll("&Uacute;","\u00DA");
		text1=text1.replaceAll("&#219;","\u00DB");
		text1=text1.replaceAll("&Ucirc;","\u00DB");
		text1=text1.replaceAll("&#220;","\u00DC");
		text1=text1.replaceAll("&Uuml;","\u00DC");
		text1=text1.replaceAll("&#224;","\u00E0");
		text1=text1.replaceAll("&agrave;","\u00E0");
		text1=text1.replaceAll("&#225;","\u00E1");
		text1=text1.replaceAll("&aacute;","\u00E1");
		text1=text1.replaceAll("&#226;","\u00E2");
		text1=text1.replaceAll("&acirc;","\u00E2");
		text1=text1.replaceAll("&#227;","\u00E3");
		text1=text1.replaceAll("&atilde;","\u00E3");
		text1=text1.replaceAll("&#228;","\u00E4");
		text1=text1.replaceAll("&auml;","\u00E4");
		text1=text1.replaceAll("&#231;","\u00E7");
		text1=text1.replaceAll("&ccedil;","\u00E7");
		text1=text1.replaceAll("&#232;","\u00E8");
		text1=text1.replaceAll("&egrave;","\u00E8");
		text1=text1.replaceAll("&#233;","\u00E9");
		text1=text1.replaceAll("&eacute;","\u00E9");
		text1=text1.replaceAll("&#234;","\u00EA");
		text1=text1.replaceAll("&ecirc;","\u00EA");
		text1=text1.replaceAll("&#235;","\u00EB");
		text1=text1.replaceAll("&euml;","\u00EB");
		text1=text1.replaceAll("&#236;","\u00EC");
		text1=text1.replaceAll("&igrave;","\u00EC");
		text1=text1.replaceAll("&#237;","\u00ED");
		text1=text1.replaceAll("&iacute;","\u00ED");
		text1=text1.replaceAll("&#238;","\u00EE");
		text1=text1.replaceAll("&icirc;","\u00EE");
		text1=text1.replaceAll("&#239;","\u00EF");
		text1=text1.replaceAll("&iuml;","\u00EF");
		text1=text1.replaceAll("&#240;","\u00F0");
		text1=text1.replaceAll("&eth;","\u00F0");
		text1=text1.replaceAll("&#241;","\u00F1");
		text1=text1.replaceAll("&ntilde;","\u00F1");
		text1=text1.replaceAll("&#242;","\u00F2");
		text1=text1.replaceAll("&ograve;","\u00F2");
		text1=text1.replaceAll("&#243;","\u00F3");
		text1=text1.replaceAll("&oacute;","\u00F3");
		text1=text1.replaceAll("&#244;","\u00F4");
		text1=text1.replaceAll("&ocirc;","\u00F4");
		text1=text1.replaceAll("&#245;","\u00F5");
		text1=text1.replaceAll("&otilde;","\u00F5");
		text1=text1.replaceAll("&#246;","\u00F6");
		text1=text1.replaceAll("&ouml;","\u00F6");
		text1=text1.replaceAll("&#249;","\u00F9");
		text1=text1.replaceAll("&ugrave;","\u00F9");
		text1=text1.replaceAll("&#250;","\u00FA");
		text1=text1.replaceAll("&uacute;","\u00FA");
		text1=text1.replaceAll("&#251;","\u00FB");
		text1=text1.replaceAll("&ucirc;","\u00FB");
		text1=text1.replaceAll("&#252;","\u00FC");
		text1=text1.replaceAll("&uuml;","\u00FC");
		text1=text1.replaceAll("&#8230;","\u2026");
		text1=text1.replaceAll("&hellip;","\u2026");
		text1=text1.replaceAll("&#160;"," ");
		text1=text1.replaceAll("&nbsp;"," ");
		text1=text1.replaceAll("&#8220;","\u201C");
		text1=text1.replaceAll("&ldquo;","\u201C");
		text1=text1.replaceAll("&#8221;","\u201D");
		text1=text1.replaceAll("&rdquo;","\u201D");
		text1=text1.replaceAll("&#8217","\u0027");
		text1=text1.replaceAll("&rsquo;","\u0027");
		text1=text1.replaceAll("&#8364;","\u20AC");
		text1=text1.replaceAll("&euro;","\u20AC");
		text1=text1.replaceAll("&#34;","\"");
		text1=text1.replaceAll("&quot;","\"");
		text1=text1.replaceAll("&#8211;","\u2013");
		text1=text1.replaceAll("&ndash;","-");
		text1=text1.replaceAll("&#180;","\u00B4");
		text1=text1.replaceAll("&acute;","\u00B4");
		text1=text1.replaceAll("&#8216;","\u2018");
		text1=text1.replaceAll("&lsquo;","\u2018");
		text1=text1.replaceAll("&#8226;","\u2022");
		text1=text1.replaceAll("&bull;","\u2022");
		text1=text1.replaceAll("&#177;","\u00B1");
		text1=text1.replaceAll("&plusmn;","\u00B1");
		text1=text1.replaceAll("&#186;","\u00BA");
		text1=text1.replaceAll("&ordm;","\u00BA");
		text1=text1.replaceAll("&#171;","\u00AB");
		text1=text1.replaceAll("&laquo;","\u00AB");
		text1=text1.replaceAll("&#187;","\u00BB");
		text1=text1.replaceAll("&raquo;","\u00BB");
		text1=text1.replaceAll("&#161;","\u00A1");
		text1=text1.replaceAll("&iexcl;","\u00A1");
		text1=text1.replaceAll("&#178;","\u00B2");
		text1=text1.replaceAll("&sup2;","\u00B2");
		text1=text1.replaceAll("&#179;","\u00B3");
		text1=text1.replaceAll("&sup3;","\u00B3");
		text1=text1.replaceAll("&nbsp;"," ");
		text1=text1.replaceAll("&NBSP;"," ");
		text1=text1.replaceAll("&amp;amp;", "&amp;");
		text1=text1.replaceAll("&amp;", "&");
		text1=text1.replaceAll("&gt;&gt;"," ");
		text1=text1.replaceAll("&lt;","<");
		text1=text1.replaceAll("&gt;",">");
		return text1;
	}

	public String createLink(String anchor) {

		int start=anchor.indexOf("href=");
		int anchorEnd=0;
		int end1,end2=0;
		String href="",content="";
		if(start!=-1){
			start=start+"href=".length();
			end1=anchor.indexOf(" ",start);
			end2=anchor.indexOf(">",start);
			if((end1!=-1 && end2!=-1)){

				if(end1<end2){
					href=anchor.substring(start,end1);

				}else{

					href=anchor.substring(start,end2);
				}
			}else if((end1!=-1 && end2==-1)){
				href=anchor.substring(start,end1);

			}else if((end1==-1 && end2!=-1)){
				href=anchor.substring(start,end2);

			}

			href=href.replaceAll("\"", "");

			if(end2!=-1){

				anchorEnd=anchor.indexOf("</a>", end2);
				if(anchorEnd!=-1){

					content=anchor.substring(end2+1,anchorEnd);
				}

			}
		}

		return href+"jfx@23582"+content;
	}

}
// SGML definition requires at least one sgml_document_entity. It is
// optional here because in practice it is not always supplied.
file_of_stories :
   (sgml_document_entity)?  (sgml_subdocument_entity | PCDATA)*
;
sgml_document_entity :
   {String c="";}
   SGML_DECLARATION prolog c=element
;
sgml_subdocument_entity :
   {String c="";}
  prolog c=element ( options {greedy=true;}:SP )?
;
// SGML definition requires at least one doc_type. It is
// optional here because in practice it is not always supplied.
//prolog
//   : (other_prolog)* (doc_type other_prolog)* (link_type other_prolog)*
//;
// Added 5-19-2003
prolog :
   (other_prolog | doc_type | link_type)*
;
doc_type :
   SGML_DOCTYPE
;
other_prolog :
     COMMENT
   | PROCESSING_INSTRUCTION
   | SP
;
link_type :
   LINK_TYPE
;
content returns [String contentStr=""]
   {String c="";}
   :
   ( options {greedy=true;}:
     sp:SP
      {
         contentStr = contentStr + sp.getText();
      }
   | pc:PCDATA
      {
         contentStr = contentStr + pc.getText();
      }
   | c=element
      {
         contentStr = contentStr + c;
      }
   | other_content
   )*
;
// The proper definition of other_content is much more than this but this
// should cover everything. For instance, the Normaliser handles entities.
other_content :
     c:COMMENT
   | m:MARKED_SECTION
   | p:PROCESSING_INSTRUCTION
   | u:SGML_USE
;
// Same as "content" but ignores text data
discardContent
   {String c="";}
   :
   ( options {greedy=true;}:
       SP
     | PCDATA
     | c=element
     | other_content
   )*
;
// Same as "content" but can only have undeclared tags
basicContent returns [String contentStr=""]
   {String c="";}
   :
   ( options {greedy=true;}:
     sp:SP
      {
         contentStr = contentStr + sp.getText();
      }
   | pc:PCDATA
      {
         contentStr = contentStr + pc.getText();
      }
   | TAG c=basicContent (options {greedy=true;}: END_TAG)?
      {
         contentStr = contentStr + c;
      }
   | other_content
   )*
;
/************************************************
*
* SGML and HTML allow no end tags. For example, the data could be:
* <story>
*    <p> paragraph one <p> paragraph two
* </story>
* Intuitively this should be treated like:
* <story>
*    <p> paragraph one </p> <p> paragraph two </p>
* </story>
* However, if <p> is allowed to contain <p> then
* "paragraph two" is inside paragraph one. So if "content" is
* used the data will be interpreted as:
* <story>
*    <p> paragraph one <p> paragraph two </p></p>
* </story>

* ...and the paragraphs will end up in reverse order!!
* One way around this is to use "basicContent" which will not
* accept any tags declared in the tokens section.
*
*************************************************/
action:
{String c="";}
	d:O_ACTION c=content
	{
		if(c!=null && c.trim().length()>0){
			c=c.trim();
			if(c.equalsIgnoreCase("I")){
				norm.getAction().set(Action.ADD);
			}
			else if(c.equalsIgnoreCase("U")){
				norm.getAction().set(Action.UPD);
			}
			else if(c.equalsIgnoreCase("D")){
				norm.getAction().set(Action.DEL);
			}
			//norm.getFSPIO().println(">>>action obtained:"+c);
		}
	}
	(options {greedy=true;}: C_ACTION)?{ }
	|E_ACTION
	 {
	 }
;
pubdate :
	{String c="";}
	d:O_PUBDATE c=content
	{
		//input:	<date>2013-11-06</date>
		//output:	PD=13-11-06
		if(c!=null && c.trim().length()>0){
			String pD[]=c.split("-");
			String pDate="";
			if(pD[0]!=null && pD[0].trim().length()>0 && pD[1]!=null && pD[1].trim().length()>0 && pD[2]!=null && pD[2].trim().length()>0 && pD[0].trim().length()==4){
				pDate=pD[0].substring(2,4)+"-"+pD[1]+"-"+pD[2];
			}
			norm.setPubDate(pDate);
			//norm.getFSPIO().println(">>>pubdate:"+pDate);
		}
	}
	(options {greedy=true;}: C_PUBDATE)?{ }
	|E_PUBDATE
	 {
	 }
;
pubtime:
	{String c="";}
	d:O_PUBTIME c=content
	{
		//input:	<time>23:19:00</time>
		//output:	ET=
		if(c!=null && c.trim().length()>0){
			c=c.trim();
			norm.getPubDate().setPubTime(c);
			norm.getPubDate().setPubTimeZone("GMT+9");
			//norm.getFSPIO().println(">>>pubtime:"+c);
		}
	}
	(options {greedy=true;}: C_PUBTIME)?{ }
	|E_PUBTIME
	 {
	 }
;
section :
	{String c="";}
	O_SECTION c=content
	{
			norm.getStoryText().append(c);
			norm.getStoryText().appendParagraph();
	}
	(options {greedy=true;}: C_SECTION)?{ }
	|d:E_SECTION
	 {
		AttrToken tok = (AttrToken) d;
        String attrIDvalue    = "";
        attrIDvalue=tok.get("code");

		String sec="";
		if(attrIDvalue.trim().length()==4){
			sec=attrIDvalue.substring(0,2);
		  norm.getSection().set(sec);
    }
	 }
;
headline :
	{String c="";}
	d:O_HEADLINE c=content
	{
		if(storyStartFlag){
			if(c!=null && c.trim().length()>0){
				c=replacement(c.trim());
				c=replaceTags(c);
				c=c.replaceAll("]]>","");
				norm.getHeadline().append(" ",c);
			}
		}
	String getID = norm.getOriginalFilename();
  int in1 = getID.indexOf("_");
  int in2 = getID.indexOf("_", in1+1);
  if(in1 != -1 && in2 != -1){
  String sLookup = getID.substring(in1 +1 ,in2);
  if(sLookup != null && sLookup.length()>0){
  	norm.lookupSourceIdentifier(sLookup);

    }
  }
	}
	(options {greedy=true;}: C_HEADLINE)?{ }
	|E_HEADLINE
	 {
	 }
;
story_start :
	{
	String c="";
	storyStartFlag = true;
	norm.storyStart();
	norm.setDefaultConfiguration();
	}
	d:O_STORY_START c=content
	{

	}
	(options {greedy=true;}: C_STORY_START)?
	{
		storyStartFlag = false;
	}
	|E_STORY_START
	 {
	 }
;
storytext :
	{String c="";}
	d:O_STORYTEXT c=content
	{

			if(c!=null && c.trim().length()>0){
				c=replacement(c.trim());
				c=replaceTags(c);
				c=c.replace("\n\n","");
				c=c.replace("\n","");
				int start2,end2=0;
				start2=c.indexOf("<a ");
				while(start2!=-1){
					end2=c.indexOf("</a>",start2);
					if(end2!=-1){
						end2=end2+"</a>".length();
						String anchor2=c.substring(start2,end2);
						String anchor3=createLink(anchor2);
						String eLink1=createElink(anchor3);
						c=c.substring(0,start2)+eLink1+c.substring(end2);
						start2=start2+2;
						start2=c.indexOf("<a ",start2);
					}
					else{
						break;
					}
				}
				c=c.replaceAll("  "," ");
				c=c.replaceAll("]]>","");
				norm.getStoryText().append(c);
				norm.getStoryText().appendParagraph();
			}
	}
	(options {greedy=true;}: C_STORYTEXT)?{ }
	|E_STORYTEXT
	 {
	 }
;
story_id :
	{String c="";}
	d:O_ID c=content
	{
		if(c!=null && c.trim().length()>0){
			c=c.trim();
			norm.getAccession().setSupplierID(c);
		}
	}
	(options {greedy=true;}: C_ID)?{ }
	|E_ID
	 {
	 }
;

paragraph1 returns [String str="";]:
	{String c="";}
	d:O_PARAGRAPH1 c=content
	{
		str=StoryBlock.PARA_STR+c;
	}
	(options {greedy=true;}: C_PARAGRAPH1)?{//str=str+StoryBlock.PARA_STR;
	}
	|E_PARAGRAPH1
	 {
	 }
;
paragraph2 returns [String str="";]:
(O_PARAGRAPH2|C_PARAGRAPH2|E_PARAGRAPH2)
{
		str=StoryBlock.PARA_STR;
 }
;
paragraph3 returns [String str="";]:
(O_PARAGRAPH3|C_PARAGRAPH3|E_PARAGRAPH3)
{
		str=StoryBlock.PARA_STR;
 }
;
h1 returns [String str="";]:
	{String c="";}
	d:O_H1 c=content
	{
		if(storyStartFlag){
			if(c!=null && c.trim().length()>0){
				c=c.trim();
				str=StoryBlock.PARA_STR+c+StoryBlock.PARA_STR;
			}
		}
	}
	(options {greedy=true;}: C_H1)?
	|E_H1
	 {
	 }
;
h2 returns [String str="";]:
	{String c="";}
	d:O_H2 c=content
	{
		if(storyStartFlag){
					if(c!=null && c.trim().length()>0){
						c=c.trim();
						str=StoryBlock.PARA_STR+c+StoryBlock.PARA_STR;
					}
		}
	}
	(options {greedy=true;}: C_H2)?
	|E_H2
	 {
	 }
;
h3 returns [String str="";]:
	{String c="";}
	d:O_H3 c=content
	{
		if(storyStartFlag){
			if(c!=null && c.trim().length()>0){
				c=c.trim();
				str=StoryBlock.PARA_STR+c+StoryBlock.PARA_STR;
			}
		}
	}
	(options {greedy=true;}: C_H3)?
	|E_H3
	 {
	 }
;
h4 returns [String str="";]:
	{String c="";}
	d:O_H4 c=content
	{
		if(storyStartFlag){
		if(c!=null && c.trim().length()>0){
			c=c.trim();
			str=StoryBlock.PARA_STR+c+StoryBlock.PARA_STR;
		}
		}
	}
	(options {greedy=true;}: C_H4)?
	|E_H4
	 {
	 }
;
h5 returns [String str="";]:
	{String c="";}
	d:O_H5 c=content
	{
		if(storyStartFlag){
			if(c!=null && c.trim().length()>0){
				c=c.trim();
				str=StoryBlock.PARA_STR+c+StoryBlock.PARA_STR;
			}
		}
	}
	(options {greedy=true;}: C_H5)?
	|E_H5
	 {
	 }
;
h6 returns [String str="";]:
	{String c="";}
	d:O_H6 c=content
	{
		if(storyStartFlag){
			if(c!=null && c.trim().length()>0){
				c=c.trim();
				str=StoryBlock.PARA_STR+c+StoryBlock.PARA_STR;
			}
		}
	}
	(options {greedy=true;}: C_H6)?
	|E_H6
	 {
	 }
;
u returns[String str="";]:
                {String c="";}
                d:O_U c=content
                {
                if (c!=null && c.trim().length()>0 ){
					str=c;
                }
                }
                (options {greedy=true;}: C_U)?
                |E_U
                 {
                 }
;
i returns[String str="";]:
                {String c="";}
                d:O_I c=content
                {
                if (c!=null && c.trim().length()>0 ){
					str=c;
                }
                }
                (options {greedy=true;}: C_I)?
                |E_I
                 {
                 }
;
b returns[String str="";]:
                {String c="";}
                d:O_B c=content
                {
                if (c!=null && c.trim().length()>0 ){
					str=c;
                }
                }
                (options {greedy=true;}: C_B)?
                |E_B
                 {
                 }
;
font returns[String str="";]:
                {String c="";}
                d:O_FONT c=content
                {
                if (c!=null && c.trim().length()>0 ){
                    str=c;
                }
                }
                (options {greedy=true;}: C_FONT )?
                |E_FONT
                 {
                 }
;
em returns[String str="";]:
                {String c="";}
                d:O_EM c=content
                {
                if (c!=null && c.trim().length()>0 ){
					str=c;
                }
                }
                (options {greedy=true;}: C_EM)?
                |E_EM
                 {
                 }
;
ul returns[String str="";]:             {String c="";}
                d:O_UL c=content
                {
                if (c!=null && c.trim().length()>0 ){
					str=c;
                }
                }
                (options {greedy=true;}: C_UL)?
                |E_UL
                 {
                 }
;
ol returns[String str="";]:             {String c="";}
                d:O_OL c=content
                {
                if (c!=null && c.trim().length()>0 ){
					str=c;
                }
                }
                (options {greedy=true;}: C_OL)?
                |E_OL
                 {
                 }
;
strong returns[String str="";]:
                {String c="";}
                d:O_STRONG c=content
                {
                if (c!=null && c.trim().length()>0 ){
					str=c;
                }
                }
                (options {greedy=true;}:C_STRONG)?
                |E_STRONG
                 {
                 }
;
litag returns [String str=""]:
                {String c="";
                }
                d:O_LI c=content
                {
                if(c!=null && c.trim().length()>0){
                    c=c.trim();
                    c="*"+" "+c;
                    c=StoryBlock.PARA_STR+c+StoryBlock.PARA_STR;
                    str=c;
                    }
                }
                (options {greedy=true;}: C_LI)?{}
                |E_LI
                 {
                 }
;
anchor returns [String str="";]:
                {String c="";}
                d:O_ANCHOR{} c=content
                {
                c=c.replaceAll(StoryBlock.PARA_STR,"");
                String eStr="";
                AttrToken tok = (AttrToken) d;
                String attrhref    = "";
                attrhref=tok.get("href");
                if(attrhref!=null&&attrhref.trim().length()>0&&(attrhref.trim().startsWith("http")||attrhref.trim().startsWith("mailto:"))&&!(c.trim().startsWith("_www.")||c.trim().startsWith("_http:")))
                {
					String startEL = StoryBlock.ELINK_START + "<ELink type="+"\""+"webpage"+"\""+" ref="+"\"";
					attrhref=attrhref.trim();
					String middle1EL = attrhref + "\""+">" +StoryBlock.ELINK_END;
					String middle2EL = c + StoryBlock.ELINK_START;
					String endEL = "</ELink>" + StoryBlock.ELINK_END;
					eStr=startEL+middle1EL+middle2EL+endEL;
					eStr=eStr.replaceAll(StoryBlock.PARA_STR,"");
					str=eStr;
                }
                else{
					str=c;
                }
                }
                (options {greedy=true;}: C_ANCHOR)?{}
                |E_ANCHOR

;
sup returns[String str="";]:
                {String c="";}
                d:O_SUP c=content
                {
                if (c!=null && c.trim().length()>0 ){
					str=c;
                }
                }
                (options {greedy=true;}: C_SUP)?
                |E_SUP
                 {
                 }
;
sub returns[String str="";]:
                {String c="";}
                d:O_SUB c=content
                {
                if (c!=null && c.trim().length()>0 ){
					str=c;
                }
                }
                (options {greedy=true;}: C_SUB)?
                |E_SUB
                 {
                 }
;
span returns[String str="";]:
                {String c="";}
                d:O_SPAN c=content
                {
                if (c!=null && c.trim().length()>0 ){
					str=c;
                }
                }
                (options {greedy=true;}: C_SPAN)?
                |E_SPAN
                 {
                 }
;
block returns[String str="";]:
                {String c="";}
                d:O_BLOCK c=content
                {
                if (c!=null && c.trim().length()>0 ){
					str=c;
                }
                }
                (options {greedy=true;}: C_BLOCK)?
                |E_BLOCK
                 {
                 }
;
bq returns[String str="";]:
                {String c="";}
                d:O_BQ c=content
                {
                if (c!=null && c.trim().length()>0 ){
					str=c;
                }
                }
                (options {greedy=true;}: C_BQ)?
                |E_BQ
                 {
                 }
;
bg returns[String str="";]:
                {String c="";}
                d:O_BG c=content
                {
                if (c!=null && c.trim().length()>0 ){
					str=c;
                }
                }
                (options {greedy=true;}: C_BG)?
                |E_BG
                 {
                 }
;
hr returns[String str="";]:
                {String c="";}
                d:O_HR c=content
                {
                if (c!=null && c.trim().length()>0 ){
					str=c;
                }
                }
                (options {greedy=true;}: C_HR)?
                |E_HR
                 {
                 }
;
div returns[String str="";]:
                {String c="";}
                d:O_DIV c=content
                {
					if (c!=null && c.trim().length()>0 ){
						String copyrightSplChr = "\u00A8"+"\u00CF";
						if(c.contains("copyright")||c.contains("Copyright")||c.contains("COPYRIGHT")||c.contains(copyrightSplChr) ){
							c="";
						}
						str=c;
					}
                }
                (options {greedy=true;}: C_DIV)?
                |E_DIV
                 {
                 }
;
imgFn :
	{String c="";}
	d:O_IMG c=content
	{

	}
	(options {greedy=true;}: C_IMG)?{ }
	|E_IMG
	 {
	 }
;
imgFull:  //image
	{String c="";}
	d:E_IMAGE c=content
	{
	   c=c.replaceAll(StoryBlock.PARA_STR,"");
     AttrToken tok = (AttrToken) d;
     String imghref="";
     imghref=tok.get("href");
     if(imghref!=null && imghref.length()>0){
       norm.getStoryText().append(imghref);
       norm.getStoryText().appendParagraph();
     }
	}
	(options {greedy=true;}: C_IMAGE)?{ }
	|O_IMAGE
	 {
	 }
;
urltag : //<url>
	{String c="";}
	d:E_URL c=content
	{
    c=c.replaceAll(StoryBlock.PARA_STR,"");
    AttrToken tok = (AttrToken) d;
    String urlhref="";
    urlhref=tok.get("href");
    if(urlhref!=null && urlhref.length()>0){
      // norm.getStoryText().append(urlhref);
      // norm.getStoryText().appendParagraph();
    }
	}
	(options {greedy=true;}: O_URL)?
	|C_URL
	 {

	 }
;
element returns [String str=""] :
    EMPTY_TAG
		|action
		|pubdate
		|pubtime
		|section
		|headline
		|story_start
		|storytext
		|story_id
		|str=paragraph1
		|str=paragraph2
		|str=paragraph3
		|str=h1
		|str=h2
		|str=h3
		|str=h4
		|str=h5
		|str=h6
		|str=anchor
		|str=em
		|str=strong
		|str=litag
		|str=ul
		|str=ol
		|str=i
		|str=u
		|str=b
		|str=font
		|str=bq
		|str=bg
		|str=block
		|str=hr
		|str=sup
		|str=sub
		|str=span
		|str=div
    |imgFn
    |imgFull
    |urltag
		| O_CDATA
		| C_CDATA
    | C_PRN
    | TAG str=content (options {greedy=true;}: END_TAG)?
;
