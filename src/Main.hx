package ;

import cx.FileTools;
import haxe.Serializer;
import haxe.Unserializer;
import neko.Lib;
import odt.Doc2Html;
import odt.Odt2Doc;
using StringTools;
/**
 * ...
 * @author Jonas Nyström
 */

class Main 
{
	static function main() 
	{		
		//-------------------------------------------------------------------------------------------------------------------------
		// read odt-file and create intermediate doc object...
		
		var odt = new Odt2Doc('test.odt');
		trace('saving content.xml from test.odt...');
		//FileTools.saveContent('content.xml', odt.getContentXml().toString());		
		trace('saving style.xml from test.odt...');
		//FileTools.saveContent('style.xml', odt.getStyleXml().toString());		
		var doc = odt.getDocElements();
		trace('saving intermediate doc format, for development overview...');
		//FileTools.saveContent('doc.xml', doc.toString());		

		//-------------------------------------------------------------------------------------------------------------------------
		// create html from intermediate doc object...
		
		var doc2html = new Doc2Html(doc);
		var html = doc2html.getHtml();
		//html = html.replace('<!DOCTYPE html>', '');
		trace('saving resulting html file...');
		FileTools.saveContent('test.html', html);		
	}	
}