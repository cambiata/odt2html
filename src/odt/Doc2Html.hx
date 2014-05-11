package odt;
import cx.HxdomTools;
import cx.PngTools;
import odt.Doc2Html.VDyn;

import odt.Odt2Doc.IDocElements;
import odt.Odt2Doc;
import hxdom.Elements;

using hxdom.DomTools;

/**
 * ...
 * @author Jonas Nyström
 */

class Doc2Html
{
	var docelement:IDocElement;
	var html:EHtml;
	var body:EBody;
	var htmlnode:VDyn;

	public function new(docelement:IDocElement) 
	{
		this.docelement = docelement;
		this.html = new EHtml();
		this.html.appendChild(new EMeta().attr(hxdom.Attr.Charset, 'utf-8'));
		this.body = new EBody();
		this.html.appendChild(this.body);
		
	}
	
	public function getHtml()
	{
		this.htmlnode = this.body;
		parseElements(this.docelement, this.htmlnode);
		var html = HxdomTools.ehtmlToHtml(this.html, true, true);
		return html;
	}

	function parseElements(docel:IDocElement, node:VDyn)
	{		
		//trace(docel);
		//var prevhtmlnode = node;
		var htmlel = getDomElement(docel, node);		
		if (htmlel == null) return;
		node.appendChild(htmlel);
		for (child in docel.children)
		{
			parseElements(child, htmlel);				
		}			
	}
	
	function getDomElement(docel:IDocElement, currentnode:VDyn):VDyn
	{
		var addItalic = false;
		var addBold = false;
		
		
		var htmlel:VDyn = switch Type.getClass(docel)
		{
			case DocRoot: new EDiv();
			case DocTextP: 
			{
				var docel:DocTextP = cast docel;
				addItalic = docel.style.italic;
				addBold = docel.style.bold;
				new EParagraph();				
			}
			case DocTextH:
			{
				var docelH:DocTextH = cast docel;
				var el = headerFactory(docelH);
				el;
			}
			case DocTextA:
				var docel:DocTextA = cast docel;
				var el = new EAnchor();
				el.attr(hxdom.Attr.Target, docel.text);
				el.attr(hxdom.Attr.Href, docel.href);
				el;
			case DocTextSpan:
				var docel:DocTextSpan = cast docel;
				var el:VDyn = new ESpan();
				if (docel.style.bold && !docel.style.italic) el = new EBold();
				if (docel.style.italic && !docel.style.bold) el = new EItalics();
				//if (!docel.style.italic && !docel.style.bold) el = currentnode;
				el;
			case DocOrderedList: new EOrderedList();
			case DocUnorderedList: new EUnorderedList();
			case DocTextListItem: new EListItem();
				
			case DocTable: new ETable();
			case DocTableRow: new ETableRow();
			case DocTableCell:new ETableCell();
			
			case DocDrawFrame: 
			{
				var imgscale = 40;
				var docel:DocDrawFrame = cast docel;
				var width = Std.int(Std.parseFloat(StringTools.replace(docel.widthinfo, 'cm', '')) * imgscale);
				var height = Std.int(Std.parseFloat(StringTools.replace(docel.heightinfo, 'cm', '')) * imgscale);
				var imgstyle = 'width:${width}px; height:${height}px;';
				var link = docel.link;
				var el  = new EDiv();
				var docimg:DocIDrawImage = cast docel.children[0];
				if (docimg.bytes.length > 0)
				{
					var imgHtml = PngTools.pngBytesToHtmlImg(docimg.bytes, imgstyle);
					el.addHtml(imgHtml);					
				}
				else
				{
					var imgTag = '<img src="$link" style="$imgstyle" />';
					el.addHtml(imgTag);					
				}
				el;
				
			}
			
			default: new EDiv();
		}		

		var temphtmlel = htmlel;
		
		//---------------------------------------------------------------------------------
		
		if (addBold) 
		{
			temphtmlel = new EBold();
			htmlel.appendChild(temphtmlel);
		}
		
		if (addItalic) 
		{
			temphtmlel = new EItalics();
			htmlel.appendChild(temphtmlel);
		}
		
		//---------------------------------------------------------------------------------
		
		temphtmlel.addText(docel.text);
		
		return htmlel;
	}
	
	function headerFactory(docelH:DocTextH):VDyn
	{
		return switch docelH.style
		{
			case EHeaderStyle.Header1: new EHeader1();
			case EHeaderStyle.Header2: new EHeader2();
			case EHeaderStyle.Header3: new EHeader3();
			case EHeaderStyle.Header4: new EHeader4();
			case EHeaderStyle.Header5: new EHeader5();
			case EHeaderStyle.Header6: new EHeader6();
		default:
			new EHeader1();
		}
	}
	
}

 typedef VDyn = VirtualElement<Dynamic>;