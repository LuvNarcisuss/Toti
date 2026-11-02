"""Render the root agreement HTML into reproducible, versioned public PDFs."""
import argparse
from html import escape
from html.parser import HTMLParser
from pathlib import Path

from reportlab.lib import colors
from reportlab.lib.enums import TA_LEFT
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import ParagraphStyle, getSampleStyleSheet
from reportlab.platypus import Paragraph, SimpleDocTemplate

ROOT = Path(__file__).resolve().parents[2]


class AgreementParser(HTMLParser):
    def __init__(self):
        super().__init__()
        self.blocks = []
        self.tag = None
        self.parts = []

    def handle_starttag(self, tag, attrs):
        if tag in ("h1", "h2", "h3", "p"):
            self.tag, self.parts = tag, []

    def handle_data(self, data):
        if self.tag:
            self.parts.append(data)

    def handle_endtag(self, tag):
        if tag == self.tag:
            self.blocks.append((tag, "".join(self.parts).strip()))
            self.tag = None


def render(name, output):
    parser = AgreementParser()
    parser.feed((ROOT / "Agreements" / (name + ".html")).read_text())
    styles = getSampleStyleSheet()
    styles.add(ParagraphStyle(name="AgreementTitle", fontName="Helvetica-Bold",
        fontSize=22, leading=28, textColor=colors.HexColor("#59364f"), spaceAfter=18))
    styles.add(ParagraphStyle(name="AgreementHeading", fontName="Helvetica-Bold",
        fontSize=12, leading=17, spaceBefore=15, spaceAfter=8, keepWithNext=True))
    styles.add(ParagraphStyle(name="AgreementSubheading", fontName="Helvetica-Bold",
        fontSize=10.5, leading=15, spaceBefore=10, spaceAfter=7, keepWithNext=True))
    styles.add(ParagraphStyle(name="AgreementBody", fontName="Helvetica",
        fontSize=9.5, leading=14, spaceAfter=8, alignment=TA_LEFT))
    mapping = {"h1": "AgreementTitle", "h2": "AgreementHeading",
               "h3": "AgreementSubheading", "p": "AgreementBody"}
    story = [Paragraph(escape(text), styles[mapping[tag]]) for tag, text in parser.blocks]

    def footer(canvas, document):
        canvas.setStrokeColor(colors.HexColor("#e7d9df"))
        canvas.line(46, 42, A4[0] - 46, 42)
        canvas.setFont("Helvetica", 8)
        canvas.setFillColor(colors.HexColor("#785e70"))
        canvas.drawString(46, 29, document.title)
        canvas.drawRightString(A4[0] - 46, 29, str(document.page))

    output.mkdir(parents=True, exist_ok=True)
    path = output / (name + ".pdf")
    document = SimpleDocTemplate(str(path), pagesize=A4, rightMargin=46,
        leftMargin=46, topMargin=46, bottomMargin=58, title=parser.blocks[0][1],
        author="Toti", invariant=1)
    document.build(story, onFirstPage=footer, onLaterPages=footer)
    print(path)


if __name__ == "__main__":
    argument_parser = argparse.ArgumentParser(description=__doc__)
    argument_parser.add_argument("--version", required=True)
    args = argument_parser.parse_args()
    from datetime import date
    version = date.fromisoformat(args.version).isoformat()
    for document_name in ("TermsOfService", "PrivacyPolicy"):
        render(document_name, ROOT / "Agreements" / version)
