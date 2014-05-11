package odt;


import cx.ZipTools;
import format.zip.Data;
import haxe.ds.StringMap.StringMap;
import haxe.io.Bytes;
import odt.Odt2Doc.DocTable;
import odt.Odt2Doc.DocTableRow;
import odt.Odt2Doc.DocTextBold;
import odt.Odt2Doc.DocTextH;
import odt.Odt2Doc.OdtStyle;

using StringTools;
/**
 * ...
 * @author Jonas Nyström
 */
class Odt2Doc
{
	var filename:String;
	var fontdecl:Xml;
	var xmlContent:Xml;
	var xmlStyle:Xml;
	var styles:OdtStyles;
	var liststyles: OdtListStyles;
	var contentnode:IDocElement;
	var zipentries:List<Entry>;
	
	public function new( filename:String) 
	{
		this.filename = filename;
		this.zipentries = ZipTools.getEntries(filename);
		var parts:OdtXmlParts = getXmlParts(this.zipentries);
		this.fontdecl = parts.fontdecl;
		this.xmlContent = parts.xmlContent;
		this.xmlStyle = parts.xmlStyle;
		this.styles = getStyles(this.xmlStyle);
		this.liststyles = getListStyles(this.xmlStyle);
	}	
	
	public function getContentXml():Xml
	{
		return this.xmlContent;
	}
	
	public function getStyleXml():Xml
	{
		return this.xmlStyle;
	}
	
	 function getXmlParts(zipEntries:List<format.zip.Data.Entry>):OdtXmlParts 
	 {			
		 var contentBytes:haxe.io.Bytes = ZipTools.getEntryData(zipEntries, 'content.xml');
		var xml = Xml.parse(contentBytes.toString());
		 var styleXml = xml.firstElement().elementsNamed('office:automatic-styles').next();
		var parts: OdtXmlParts = 
		{		
			xmlContent: xml.firstElement().elementsNamed('office:body').next().firstElement(),
			xmlStyle: xml.firstElement().elementsNamed('office:automatic-styles').next(),			
			fontdecl: null,
		}		
		return parts;
	}	
	
	function getStyles(xml:Xml) : OdtStyles
	{
		var result = new OdtStyles();
		for (e in xml)
		{
			if (Std.string(e.nodeType) != 'element') continue;
			if (e.nodeName != 'style:style') continue;
			var styleName = e.get('style:name');
			var styleFamily = e.get('style:family');
			if (!(styleFamily == 'text' || styleFamily == 'paragraph')) continue;
			var bold = (e.firstElement().get('fo:font-weight') =='bold');
			var italic = (e.firstElement().get('fo:font-style') == 'italic');
			var psn = e.get('style:parent-style-name');
			var style:OdtStyle = { name:styleName, italic:italic, bold:bold , parentStyleName:psn };
			result.set(styleName, style );
		}
		return result;
	}
	
	function getListStyles(xml:Xml) : OdtListStyles
	{
		var result = new OdtListStyles();
		for (e in xml)
		{
			if (Std.string(e.nodeType) != 'element') continue;
			if (e.nodeName != 'text:list-style') continue;
			var styleName = e.get('style:name');
			var listType = e.firstChild().nodeName;
			var number = (listType == 'text:list-level-style-number' );
			var style:OdtListStyle = { name:styleName, number : number };
			result.set(styleName, style);
		}
		return result;
	}
	
	public function getDocElements(xml:Xml = null)
	{		
		this.contentnode = new DocRoot();		
		this.recursiveParser((xml == null) ? this.xmlContent : xml);	
		return this.contentnode;		
	}
	
	function recursiveParser(xml:Xml)
	{
		for (e in xml)
		{
			var nodeType = Std.string(e.nodeType);
			switch (nodeType) 
			{
				case 'element':
					var childnode = getChildNode(e);
					if (childnode == null) continue;
					var currentnode = this.contentnode;
					this.contentnode.addChild(childnode);
					this.contentnode = childnode;
					recursiveParser(e);
					this.contentnode = currentnode;					
				case 'pcdata':
					var text = e.toString();
					this.contentnode.setText(text);
			}
			
		}		
	}
	
	
	function getChildNode(e:Xml): IDocElement
	{
		var nodeName = e.nodeName;
		var styleName = e.get('text:style-name');		
		
		var returnNode:IDocElement = switch nodeName
		{
			
		case OdtNodename.OfficeText: new DocOfficeText();
		case OdtNodename.TextP: 
		{
			var style:OdtStyle = this.styles.get(styleName);	
			var p = new DocTextP(style);
			p;
		}
		case OdtNodename.TextH: 
			{
				var el:DocTextH = this.getHeaderElement(styleName);
				if (el == null) 
				{
					var style:OdtStyle = this.styles.get(styleName);
					el = this.getHeaderElement(style.parentStyleName);
				}
				if (el == null) el = new DocTextH(EHeaderStyle.Header1);
				el;
			}
		case OdtNodename.TextA:
			{
				var href = e.get('xlink:href');
				var target = e.get('office:target-frame-name');
				new DocTextA(href, target);
			}
		case OdtNodename.TextSpan: 
			{
				var style:OdtStyle = this.styles.get(styleName);						
				return new DocTextSpan(style);
			}
		case OdtNodename.TextList: 
			{
				new DocTextList();
				var styleName = e.get('text:style-name');
				var listStyle:OdtListStyle = this.liststyles.get(styleName);
				(listStyle.number) ? new DocOrderedList() : new DocUnorderedList();					
			}
		case OdtNodename.TextListItem: new DocTextListItem();
		case OdtNodename.TextSoftPagebreak: new DocTextSoftPagebreak();	
		case OdtNodename.TextSequenceDecls: null; // new DocTextSequenceDecls();			
		case OdtNodename.TextSequenceDecl: null; // new DocTextSequenceDecl();	
		
		case OdtNodename.Table: new DocTable();
		case OdtNodename.TableRow: new DocTableRow();
		case OdtNodename.TableCell: new DocTableCell();
		
		case OdtNodename.DrawFrame:
		{
			var width = e.get('svg:width'); // Std.int(Std.parseFloat(StringTools.replace(e.get('svg:width'), 'cm', '')) * imgscale);
			var height = e.get('svg:height'); // Std.int(Std.parseFloat(StringTools.replace(e.get('svg:height'), 'cm', '')) * imgscale);
			var link = e.firstChild().get('xlink:href');	
			var docDrawFrame = new DocDrawFrame(width, height, link);
			if (link.startsWith('Pictures/'))
			{
				try  
				{
					if (this.zipentries == null) throw "png zip entry error";
					var imgBytes = ZipTools.getEntryData(this.zipentries, link);
					docDrawFrame.children.push(new DocIDrawImage(link, imgBytes));
				}
				catch (e:Dynamic)
				{
					
				}
			} 
			else
			{
				docDrawFrame.children.push(new DocIDrawImage(link, null));
			}
			return docDrawFrame;
		}
		
		case OdtNodename.DrawImage:
		{	
			null;
		}
		
		default:  
			{
				new DocUnknown(nodeName, styleName);				
			}
		}
		
		return returnNode;
	}
	
	function getHeaderElement(id:String)
	{
		return switch id
		{					
			case 'Heading_20_1': new DocTextH(EHeaderStyle.Header1);
			case 'Heading_20_2': new DocTextH(EHeaderStyle.Header2);
			case 'Heading_20_3': new DocTextH(EHeaderStyle.Header3);
			case 'Heading_20_4': new DocTextH(EHeaderStyle.Header4);
			case 'Heading_20_5': new DocTextH(EHeaderStyle.Header5);
			default:  null;
		}		
	}
	
}

typedef OdtStyles = StringMap<OdtStyle>;

typedef OdtStyle = 
{
	name:String,
	bold:Bool,
	italic:Bool,	
	parentStyleName:String,
}

typedef OdtListStyles = StringMap<OdtListStyle>;

typedef OdtListStyle = 
{
	name:String,
	number:Bool,
}


typedef OdtXmlParts = 
{
	xmlContent:Xml,
	xmlStyle:Xml,
	fontdecl:Xml,
}


@:enum
abstract OdtNodename(String)
{
	var OfficeText = 'office:text';
	var TextP =  'text:p';
	var TextH = 'text:h';
	var TextA = 'text:a';
	var TextSpan = 'text:span';
	var TextList = 'text:list';
	var TextListItem = 'text:list-item';
	var TextBookmark = 'text:bookmark';
	var TextSoftPagebreak = 'text:soft-page-break';
	var TextSequenceDecls = 'text:sequence-decls';
	var TextSequenceDecl = 'text:sequence-decl';
	var Table = 'table:table';
	var TableRow = 'table:table-row' ;
	var TableCell = 'table:table-cell';
	var DrawFrame = 'draw:frame';
	var DrawImage = 'draw:image';
}

interface IDocElement 
{
	function addChild(child:IDocElement):Void;
	var children(default, null):IDocElements;
	function setText(text:String):Void;
	var text(default, null):String;
	function toString():String;
}

typedef IDocElements = Array<IDocElement>;


class DocElement implements IDocElement
{
	 public var children(default, null):IDocElements;
	 public var text(default, null):String;
	public function new( ) 
	{
		this.text = '';
		this.children = [];
	}
	
	/* INTERFACE odt.OdtDocument.IElement */
	
	public function addChild(child:IDocElement):Void 
	{
		this.children.push(child);
	}
	//public function getChildren():IDocElements return this.children;
	
	public function setText(text:String):Void 
	{
		this.text = text;
	}
	//public function getText():String return this.text;
	
	public function toString():String
	{
		var classname =  Type.getClassName(Type.getClass(this)).replace('odt.', '');
		var cstr = '';
		for (child in this.children) cstr += child.toString();
		var txt = (this.text == null) ? ' ' : this.text.trim();
		txt = txt.replace('\n', '');
		txt = txt.replace('\t', '');
		txt = txt.replace('\r', '');
		txt = txt.trim();
		txt = (txt.length > 0 && txt != 'null') ? ' text="$txt"' : '';
		var style = this.getStyleString();
		var str = '<$classname $txt $style>$cstr</$classname>';
		return str;
	}
	
	public function getStyleString():String
	{
		return '';
	}
}


class DocRoot extends DocElement { public function new(  ) {super(); } }
class DocTextP extends DocElement 
{ 
	public var style(default, null):OdtStyle;
	public function new( style:OdtStyle=null ) 
	{ 
		super(); 
		this.style = style;
	} 
}
class DocTextH extends DocElement 
{ 
	public var style(default, null):EHeaderStyle;
	public function new( style:EHeaderStyle  ) 
	{	
		super(); 
		this.style = style;
	}
	
	override public function getStyleString():String
	{
		return 'style="${this.style}"';
	}
}
class DocTextA extends DocElement 
{ 
	public var href(default, null):String;
	public var target(default, null):String;
	public function new( href:String, target:String ) 
	{ 
		super(); 
		this.href = href;
		this.target = target;
	} 
}
class DocTextList extends DocElement { public function new(  ) {super(); } }
class DocTextListItem extends DocElement { public function new(  ) {super(); } }
class DocTextBookmark extends DocElement { public function new(  ) {super(); } }
class DocTextSoftPagebreak extends DocElement { public function new(  ) {super(); } }
class DocTextSequenceDecls extends DocElement { public function new(  ) {super(); } }
class DocTextSequenceDecl extends DocElement { public function new(  ) {super(); } }
class DocTable extends DocElement { public function new(  ) {super(); } }
class DocTableRow extends DocElement { public function new(  ) {super(); } }
class DocTableCell extends DocElement { public function new(  ) {super(); } }
class DocDrawFrame extends DocElement 
{ 
	public var widthinfo(default, null):String;
	public var heightinfo(default, null):String;
	public var link(default, null):String;
	public function new(widthinfo:String, heightinfo:String, link:String ) 
	{ 
		super(); 	
		this.widthinfo = widthinfo;
		this.heightinfo = heightinfo;
		this.link = link;
	} 

	override public function getStyleString():String 
	{
		var width = 'width="${this.widthinfo}"';
		var height = 'height="${this.heightinfo}"';
		var link = 'link="${this.link}"';
		return '$width $height $link';
	}	
	
}
class DocTextSpan extends DocElement 
{ 	
	public var style(default, null):OdtStyle;
	public function new( style:OdtStyle ) 
	{
		super(); 
		this.style = style;
	} 
	
	override public function getStyleString():String 
	{
		var bold = this.style.bold ? 'bold="true"' : '';
		var italic = this.style.italic ? 'italic="true"': '';
		var name = 'name="${this.style.name}"';
		return '$name $bold $italic';
	}
}
class DocTextBold extends DocElement { public function new(  ) {super(); } }
class DocTextItalic extends DocElement { public function new(  ) {super(); } }
class DocOrderedList extends DocElement { public function new(  ) {super(); } }
class DocUnorderedList extends DocElement { public function new(  ) { super(); } }
class DocOfficeText extends DocElement { public function new(  ) { super(); } }
class DocUnknown extends DocElement 
{ 
	public var nodename(default, null):String;
	public var stylename(default, null):String;
	public function new( nodename:String, stylename:String ) 
	{ 
		super(); 
		this.nodename = nodename;
		this.stylename = stylename;
	} 
}
class DocIDrawImage extends DocElement
{
	public var link(default, null):String;
	public var bytes(default, null):Bytes;
	public function new(link:String, bytes:Bytes)
	{
		super();
		this.link = link;
		this.bytes = bytes;
	}
	
	override public function getStyleString():String 
	{	
		var length = (this.bytes != null) ? Std.string(this.bytes.length) + ' bytes' : '';
		return 'link="${this.link}" data="$length"';
	}
}

@:enum
abstract EHeaderStyle(Int)
{
	var Header1 = 1;
	var Header2 =2;
	var Header3 =3;
	var Header4 =4;
	var Header5 =5;
	var Header6 =6;
}