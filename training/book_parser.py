#!/usr/bin/env python3
"""
EPUB to XML Parser - Versión Corregida
Detecta capítulos reales y filtra contenido irrelevante
Usage: python3 epub_parser.py ruta/al/archivo.epub
"""

import sys
import os
import re
import zipfile
from pathlib import Path
from xml.etree import ElementTree as ET
from typing import Dict, List, Any, Optional, Tuple

try:
    from bs4 import BeautifulSoup
except ImportError:
    print("⚠️ Instalando BeautifulSoup...")
    os.system("pip3 install beautifulsoup4")
    from bs4 import BeautifulSoup

class SmartEPUBParser:
    """Parser inteligente de EPUBs que detecta capítulos reales"""
    
    # Palabras clave para identificar secciones irrelevantes
    IRRELEVANT_KEYWORDS = [
        'imprint', 'dedication', 'dedicatoria', 'preface', 'prefacio',
        'introduction', 'introducción', 'contents', 'table of contents',
        'indice', 'bibliography', 'bibliografía', 'index', 'apendix',
        'appendice', 'colophon', 'colofón', 'uncopyright', 'endnotes',
        'notas', 'cover', 'portada', 'titlepage', 'portadilla'
    ]
    
    def __init__(self, epub_path: str):
        self.epub_path = Path(epub_path)
        self.temp_dir = Path("epub_temp")
        self.namespaces = {
            'dc': 'http://purl.org/dc/elements/1.1/',
            'opf': 'http://www.idpf.org/2007/opf',
            'xhtml': 'http://www.w3.org/1999/xhtml',
            'ncx': 'http://www.daisy.org/z3986/2005/ncx/'
        }
        
        self.metadata = {
            'title': 'Sin título',
            'author': 'Autor desconocido',
            'release': '2026-08-01'
        }
        self.manifest = {}
        self.spine = []
        self.toc = []
        self.images = []
        self.cover_image = None
        self.content_files = []
        self.chapters = []
        self.opf_path = None
        
    def parse(self) -> Dict[str, Any]:
        """Punto de entrada principal"""
        print("📖 Procesando:", self.epub_path.name)
        print("=" * 60)
        
        if not self.epub_path.exists():
            raise FileNotFoundError(f"EPUB no encontrado: {self.epub_path}")
        
        self._extract_zip()
        self._find_opf()
        self._parse_metadata()
        self._parse_manifest_spine()
        self._parse_toc()
        self._extract_content_files()
        self._extract_images()
        self._smart_chapter_detection()
        self._cleanup_temp()
        
        return {
            'metadata': self.metadata,
            'chapters': self.chapters,
            'images': self.images,
            'cover_image': self.cover_image,
            'title': self.metadata.get('title', 'Sin título'),
            'author': self.metadata.get('author', 'Autor desconocido'),
            'release': self.metadata.get('release', '2026-08-01')
        }
    
    def _extract_zip(self):
        """Extrae el EPUB como ZIP"""
        print("📦 Extrayendo EPUB...")
        self.temp_dir.mkdir(exist_ok=True)
        
        try:
            with zipfile.ZipFile(self.epub_path, 'r') as z:
                z.extractall(self.temp_dir)
                print(f"   Archivos extraídos: {len(z.namelist())}")
        except Exception as e:
            raise RuntimeError(f"Error al extraer EPUB: {e}")
    
    def _find_opf(self):
        """Encuentra el archivo OPF"""
        container_path = self.temp_dir / "META-INF" / "container.xml"
        
        if container_path.exists():
            try:
                tree = ET.parse(container_path)
                root = tree.getroot()
                ns = {'c': 'urn:oasis:names:tc:opendocument:xmlns:container'}
                opf_path_elem = root.find('.//c:rootfile', ns)
                
                if opf_path_elem is not None:
                    self.opf_path = self.temp_dir / opf_path_elem.get('full-path')
                    print(f"   OPF encontrado: {self.opf_path.name}")
                    return
            except Exception as e:
                print(f"   ⚠️ Error leyendo container.xml: {e}")
        
        # Buscar cualquier archivo .opf
        opf_files = list(self.temp_dir.glob("**/*.opf"))
        if opf_files:
            self.opf_path = opf_files[0]
            print(f"   OPF encontrado: {self.opf_path.name}")
        else:
            raise FileNotFoundError("No se encontró archivo OPF")
    
    def _parse_metadata(self):
        """Extrae metadatos del OPF"""
        print("📝 Extrayendo metadatos...")
        
        if self.opf_path is None:
            return
        
        try:
            tree = ET.parse(self.opf_path)
            root = tree.getroot()
            
            metadata = root.find('opf:metadata', self.namespaces)
            if metadata is not None:
                title_elem = metadata.find('dc:title', self.namespaces)
                if title_elem is not None and title_elem.text:
                    self.metadata['title'] = title_elem.text.strip()
                
                creator_elem = metadata.find('dc:creator', self.namespaces)
                if creator_elem is not None and creator_elem.text:
                    self.metadata['author'] = creator_elem.text.strip()
                
                date_elem = metadata.find('dc:date', self.namespaces)
                if date_elem is not None and date_elem.text:
                    self.metadata['release'] = date_elem.text.strip()
            
            print(f"   Título: {self.metadata['title']}")
            print(f"   Autor: {self.metadata['author']}")
            
        except Exception as e:
            print(f"   ⚠️ Error al parsear metadatos: {e}")
    
    def _parse_manifest_spine(self):
        """Lee manifest y spine"""
        print("📚 Leyendo estructura del libro...")
        
        if self.opf_path is None:
            return
        
        try:
            tree = ET.parse(self.opf_path)
            root = tree.getroot()
            
            manifest = root.find('opf:manifest', self.namespaces)
            if manifest is not None:
                for item in manifest.findall('opf:item', self.namespaces):
                    href = item.get('href')
                    if href:
                        self.manifest[href] = {
                            'href': href,
                            'mime_type': item.get('media-type', ''),
                            'id': item.get('id', '')
                        }
            
            spine = root.find('opf:spine', self.namespaces)
            if spine is not None:
                for item in spine.findall('opf:itemref', self.namespaces):
                    ref_id = item.get('idref')
                    if ref_id:
                        self.spine.append(ref_id)
            
            print(f"   Archivos en manifest: {len(self.manifest)}")
            print(f"   Orden de lectura: {len(self.spine)}")
            
        except Exception as e:
            print(f"   ⚠️ Error: {e}")
    
    def _parse_toc(self):
        """Lee la tabla de contenidos"""
        print("📑 Extrayendo TOC...")
        
        if self.opf_path is None:
            return
        
        ncx_found = False
        for href, info in self.manifest.items():
            if 'ncx' in href.lower() or info.get('mime_type') == 'application/x-dtbncx+xml':
                ncx_path = self.opf_path.parent / href
                if ncx_path.exists():
                    self._parse_ncx(ncx_path)
                    ncx_found = True
                    break
        
        if not ncx_found:
            self._create_toc_from_spine()
        
        print(f"   Puntos TOC: {len(self.toc)}")
    
    def _parse_ncx(self, ncx_path: Path):
        """Parsear NCX"""
        try:
            tree = ET.parse(ncx_path)
            root = tree.getroot()
            
            for nav_point in root.findall('.//ncx:navPoint', self.namespaces):
                label = nav_point.find('.//ncx:navLabel/ncx:text', self.namespaces)
                content = nav_point.find('.//ncx:content', self.namespaces)
                
                if label is not None and content is not None:
                    title = label.text.strip() if label.text else ''
                    self.toc.append({
                        'title': title,
                        'href': content.get('src', ''),
                        'order': int(nav_point.get('playOrder', 0)),
                        'children': []
                    })
        except Exception as e:
            print(f"   ⚠️ Error parseando NCX: {e}")
    
    def _create_toc_from_spine(self):
        """Crear TOC desde spine"""
        for idref in self.spine:
            for href, info in self.manifest.items():
                if info.get('id') == idref:
                    title = Path(href).stem.replace('_', ' ').replace('-', ' ')
                    title = ' '.join(word.capitalize() for word in title.split())
                    self.toc.append({
                        'title': title,
                        'href': href,
                        'children': []
                    })
                    break
    
    def _extract_content_files(self):
        """Extrae contenido de archivos XHTML"""
        print("📄 Extrayendo contenido...")
        
        content_hrefs = []
        for href, info in self.manifest.items():
            mime_type = info.get('mime_type', '')
            if mime_type.startswith('application/xhtml+xml') or \
               href.endswith(('.html', '.xhtml', '.htm')):
                content_hrefs.append(href)
        
        content_hrefs.sort()
        print(f"   Archivos de contenido: {len(content_hrefs)}")
        
        for href in content_hrefs:
            file_path = self.opf_path.parent / href
            if file_path.exists():
                try:
                    with open(file_path, 'r', encoding='utf-8') as f:
                        content = f.read()
                    
                    soup = BeautifulSoup(content, 'html.parser')
                    for tag in soup(["script", "style"]):
                        tag.decompose()
                    
                    text = soup.get_text(separator=' ', strip=True)
                    
                    # Extraer encabezados
                    headers = []
                    for h in soup.find_all(['h1', 'h2', 'h3', 'h4']):
                        header_text = h.get_text(strip=True)
                        if header_text and len(header_text) < 200:
                            headers.append(header_text)
                    
                    # Buscar imágenes en este archivo
                    for img in soup.find_all('img'):
                        src = img.get('src', '')
                        if src:
                            img_info = {
                                'src': src,
                                'alt': img.get('alt', ''),
                                'file': str(file_path)
                            }
                            if img_info not in self.images:
                                self.images.append(img_info)
                    
                    file_info = {
                        'href': href,
                        'full_text': text,
                        'headers': headers,
                        'length': len(text),
                        'has_content': len(text) > 200
                    }
                    self.content_files.append(file_info)
                    
                except Exception as e:
                    pass
    
    def _extract_images(self):
        """Extrae imágenes"""
        print("🖼️ Extrayendo imágenes...")
        
        os.makedirs('images', exist_ok=True)
        extracted = 0
        
        for img_info in self.images:
            src = img_info.get('src', '')
            if not src:
                continue
            
            # Resolver ruta
            file_path = Path(img_info.get('file', ''))
            img_path = file_path.parent / src
            
            if not img_path.exists():
                # Intentar buscar en el directorio principal
                alt_path = self.opf_path.parent / src
                if alt_path.exists():
                    img_path = alt_path
            
            if img_path.exists():
                filename = img_path.name
                if not filename:
                    filename = f'image_{extracted+1}.jpg'
                
                # Limpiar nombre
                filename = re.sub(r'[^a-zA-Z0-9._-]', '_', filename)
                dest = Path('images') / filename
                
                try:
                    import shutil
                    shutil.copy2(img_path, dest)
                    img_info['extracted'] = str(dest)
                    extracted += 1
                    
                    if 'cover' in str(file_path).lower() or 'cover' in src.lower():
                        self.cover_image = img_info
                except Exception as e:
                    pass
        
        # Buscar imágenes en el manifest
        for href, info in self.manifest.items():
            mime_type = info.get('mime_type', '')
            if mime_type.startswith('image/'):
                img_path = self.opf_path.parent / href
                if img_path.exists():
                    filename = img_path.name
                    dest = Path('images') / filename
                    try:
                        import shutil
                        shutil.copy2(img_path, dest)
                        
                        img_info = {
                            'src': href,
                            'alt': '',
                            'extracted': str(dest),
                            'file': str(img_path)
                        }
                        
                        # Verificar si ya existe
                        if not any(i.get('src') == href for i in self.images):
                            self.images.append(img_info)
                            extracted += 1
                            
                        if 'cover' in str(href).lower():
                            self.cover_image = img_info
                    except Exception as e:
                        pass
        
        print(f"   Imágenes extraídas: {extracted}")
    
    def _is_relevant_chapter(self, title: str, text: str) -> Tuple[bool, str]:
        """Determina si un capítulo es relevante"""
        title_lower = title.lower()
        text_lower = text[:500].lower()
        
        # Verificar si es irrelevante
        for keyword in self.IRRELEVANT_KEYWORDS:
            if keyword in title_lower:
                return False, 'irrelevant'
            if keyword in text_lower and len(text) < 1000:
                return False, 'irrelevant'
        
        # Verificar si tiene contenido sustancial
        if len(text) > 2000:
            return True, 'content'
        
        # Verificar si tiene encabezados significativos
        if len(text) > 1000 and title and len(title) > 3:
            return True, 'section'
        
        return False, 'unknown'
    
    def _smart_chapter_detection(self):
        """Detección inteligente de capítulos"""
        print("🧠 Detectando capítulos reales...")
        
        real_chapters = []
        
        # Procesar archivos de contenido
        for file_info in self.content_files:
            if not file_info.get('has_content', False):
                continue
            
            # Usar el primer encabezado como título
            title = file_info.get('headers', [''])[0] if file_info.get('headers') else ''
            if not title:
                title = Path(file_info['href']).stem.replace('_', ' ').replace('-', ' ')
                title = ' '.join(word.capitalize() for word in title.split())
            
            text = file_info.get('full_text', '')
            
            # Determinar si es relevante
            is_relevant, chapter_type = self._is_relevant_chapter(title, text)
            
            if is_relevant:
                real_chapters.append({
                    'title': title,
                    'content': text,
                    'type': chapter_type,
                    'href': file_info['href']
                })
        
        # Si no hay capítulos, usar el TOC
        if not real_chapters and self.toc:
            for toc_item in self.toc:
                title = toc_item.get('title', '')
                href = toc_item.get('href', '')
                
                # Buscar contenido
                for file_info in self.content_files:
                    if file_info['href'] == href or href in file_info['href']:
                        is_relevant, _ = self._is_relevant_chapter(title, file_info['full_text'])
                        if is_relevant:
                            real_chapters.append({
                                'title': title,
                                'content': file_info['full_text'],
                                'type': 'toc_chapter',
                                'href': href
                            })
                        break
        
        # Si aún no hay capítulos, crear uno principal
        if not real_chapters:
            largest_file = max(self.content_files, key=lambda x: x.get('length', 0))
            if largest_file.get('has_content', False):
                title = self.metadata.get('title', 'Contenido completo')
                real_chapters.append({
                    'title': title,
                    'content': largest_file.get('full_text', ''),
                    'type': 'main',
                    'href': largest_file.get('href', '')
                })
        
        # Dividir capítulos largos
        self.chapters = []
        for chapter in real_chapters:
            pages = self._split_pages(chapter['content'], 500)
            self.chapters.append({
                'title': chapter['title'],
                'content': chapter['content'],
                'pages': pages,
                'type': chapter.get('type', 'chapter')
            })
        
        print(f"   Capítulos detectados: {len(self.chapters)}")
    
    def _split_pages(self, text: str, words_per_page: int = 500) -> List[str]:
        """Divide texto en páginas"""
        if not text:
            return []
        
        words = text.split()
        pages = []
        
        for i in range(0, len(words), words_per_page):
            page_words = words[i:i + words_per_page]
            pages.append(' '.join(page_words))
        
        return pages
    
    def _cleanup_temp(self):
        """Limpia archivos temporales"""
        import shutil
        if self.temp_dir.exists():
            shutil.rmtree(self.temp_dir)
            print("🧹 Limpiando archivos temporales...")
    
    def get_cover_description(self) -> str:
        """Genera descripción de la portada"""
        if self.cover_image:
            alt = self.cover_image.get('alt', '')
            if alt:
                return f"Portada del libro '{self.metadata['title']}' - {alt}"
            return f"Portada del libro '{self.metadata['title']}'"
        elif self.images:
            return f"Imagen del libro '{self.metadata['title']}'"
        return f"Portada del libro '{self.metadata['title']}' por {self.metadata['author']}"

class XMLGenerator:
    """Genera XML en el formato requerido"""
    
    def __init__(self, content: Dict[str, Any]):
        self.content = content
    
    def generate(self) -> str:
        """Genera el XML final"""
        print("📝 Generando XML estructurado...")
        
        xml_lines = []
        xml_lines.append('<?xml version="1.0" encoding="utf-8"?>')
        xml_lines.append('<book>')
        
        # Título
        title = self.content.get('title', 'Sin título')
        xml_lines.append(f'\t<title>{self._escape(title)}</title>')
        
        # Autor
        author = self.content.get('author', 'Autor desconocido')
        xml_lines.append(f'\t<author>{self._escape(author)}</author>')
        
        # Fecha
        release = self.content.get('release', '2026-08-01')
        xml_lines.append(f'\t<release>{self._escape(release)}</release>')
        
        # Portada
        xml_lines.append('\t<cover>')
        xml_lines.append('\t    <image>')
        
        cover_img = self.content.get('cover_image')
        if cover_img:
            full_path = cover_img.get('extracted', cover_img.get('path', ''))
            if full_path:
                xml_lines.append(f'\t\t\t<full_path>./{full_path}</full_path>')
            else:
                xml_lines.append('\t\t\t<full_path></full_path>')
            description = self.content.get('cover_description', self._generate_cover_description())
            xml_lines.append(f'\t\t\t<description>{self._escape(description)}</description>')
        else:
            xml_lines.append('\t\t\t<full_path></full_path>')
            xml_lines.append('\t\t\t<description></description>')
        
        xml_lines.append('\t    </image>')
        xml_lines.append('\t</cover>')
        
        # Capítulos
        chapters = self.content.get('chapters', [])
        
        if chapters:
            for chapter in chapters:
                xml_lines.extend(self._generate_chapter(chapter))
        else:
            # Si no hay capítulos, crear uno con todo el texto
            full_text = self.content.get('full_text', '')
            if full_text:
                xml_lines.append('\t<chapter title="Contenido completo" indent="5-tab">')
                xml_lines.append('\t\t<quote></quote>')
                pages = self._split_pages(full_text, 500)
                for page in pages[:50]:  # Limitar páginas
                    if page.strip():
                        xml_lines.append('\t\t<page>')
                        xml_lines.append(f'\t\t\t{self._escape(page)}')
                        xml_lines.append('\t\t</page>')
                xml_lines.append('\t</chapter>')
        
        xml_lines.append('</book>')
        
        result = '\n'.join(xml_lines)
        print(f"   XML generado: {len(result)} caracteres")
        print(f"   Capítulos en XML: {len(chapters)}")
        return result
    
    def _generate_chapter(self, chapter: Dict) -> List[str]:
        """Genera un capítulo"""
        lines = []
        title = chapter.get('title', '')
        pages = chapter.get('pages', [])
        
        if not pages and chapter.get('content'):
            pages = self._split_pages(chapter['content'], 500)
        
        # Solo agregar si hay contenido
        if not pages:
            return lines
        
        lines.append(f'\t<chapter title="{self._escape(title)}" indent="5-tab">')
        lines.append('\t\t<quote></quote>')
        
        for page in pages[:30]:  # Limitar a 30 páginas por capítulo
            if page.strip():
                lines.append('\t\t<page>')
                lines.append(f'\t\t\t{self._escape(page)}')
                lines.append('\t\t</page>')
        
        lines.append('\t</chapter>')
        return lines
    
    def _split_pages(self, text: str, words_per_page: int = 500) -> List[str]:
        """Divide texto en páginas"""
        if not text:
            return []
        
        words = text.split()
        pages = []
        
        for i in range(0, len(words), words_per_page):
            page_words = words[i:i + words_per_page]
            pages.append(' '.join(page_words))
        
        return pages
    
    def _generate_cover_description(self) -> str:
        """Genera descripción de portada"""
        title = self.content.get('title', '')
        author = self.content.get('author', '')
        desc = f"Portada del libro '{title}'"
        if author and author != 'Autor desconocido':
            desc += f" por {author}"
        return desc
    
    def _escape(self, text: Any) -> str:
        """Escapa caracteres para XML"""
        if text is None:
            return ''
        
        text = str(text)
        text = text.replace('&', '&amp;')
        text = text.replace('<', '&lt;')
        text = text.replace('>', '&gt;')
        text = text.replace('"', '&quot;')
        text = text.replace("'", '&apos;')
        
        # Limpiar caracteres inválidos
        text = re.sub(r'[^\x09\x0A\x0D\x20-\uD7FF\uE000-\uFFFD]', '', text)
        text = re.sub(r'\s+', ' ', text)
        
        return text.strip()

def main():
    if len(sys.argv) < 2:
        print("Uso: python3 epub_parser.py ruta/al/archivo.epub")
        print("\nOpciones:")
        print("  --output DIR  Directorio de salida (default: ./)")
        sys.exit(1)
    
    epub_path = sys.argv[1]
    output_dir = '.'
    
    for i, arg in enumerate(sys.argv):
        if arg == '--output' and i + 1 < len(sys.argv):
            output_dir = sys.argv[i + 1]
    
    try:
        parser = SmartEPUBParser(epub_path)
        content = parser.parse()
        content['cover_description'] = parser.get_cover_description()
        
        # Texto completo para respaldo
        full_text = ' '.join([ch.get('content', '') for ch in content.get('chapters', [])])
        content['full_text'] = full_text
        
        generator = XMLGenerator(content)
        xml_output = generator.generate()
        
        output_name = Path(epub_path).stem + '.xml'
        output_path = Path(output_dir) / output_name
        output_path.parent.mkdir(parents=True, exist_ok=True)
        
        with open(output_path, 'w', encoding='utf-8') as f:
            f.write(xml_output)
        
        print("=" * 60)
        print("✅ PROCESO COMPLETADO")
        print(f"📄 XML generado: {output_path}")
        print(f"📊 Capítulos: {len(content.get('chapters', []))}")
        print(f"🖼️  Imágenes: {len(content.get('images', []))}")
        print("=" * 60)
        
    except Exception as e:
        print(f"❌ Error: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)

if __name__ == "__main__":
    main()