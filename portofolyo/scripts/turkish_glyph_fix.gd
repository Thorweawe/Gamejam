class_name TurkishGlyphFix
extends Translation
## Fredoka fontunda hazir "ş / Ş" harfi yok; motor bunu "s + birlestirici cengel" diye parcaliyor ve
## fontta cengelin baglanti noktasi olmadigi icin cengel bir SONRAKI harfin altina kayiyordu
## ("Basķanım"). Ayni fontta virgullu "ș / Ș" (Romence) dogru konumlaniyor ve neredeyse ayni gorunuyor.
## Bu ceviri katmani ekrana yazilan her metinde (Label, Button, RichTextLabel, Label3D...) ş -> ș,
## Ş -> Ș yapar. Kaynak metinler (dialogs.gd, seslendirme kimlikleri, kayitlar) degismez.
## Kurulum: Settings.apply() -> TurkishGlyphFix.install() (menude ve oyunda ilk calisan yer).

static var _installed := false


static func install() -> void:
	if _installed:
		return
	_installed = true
	var t := TurkishGlyphFix.new()
	t.locale = "tr"
	TranslationServer.add_translation(t)
	TranslationServer.set_locale("tr")


func _get_message(src_message: StringName, _context: StringName) -> StringName:
	var s := String(src_message)
	if s.contains("ş") or s.contains("Ş"):
		return StringName(s.replace("ş", "ș").replace("Ş", "Ș"))
	return &""  # bos = cevirisi yok, metin oldugu gibi kalir
