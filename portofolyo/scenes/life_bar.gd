extends Node2D 

# --- DÜĞÜM BAĞLANTILARI ---
@onready var hp_bar_money: ProgressBar = $hp_bar_money # Sarı bar
@onready var money_label: Label = $hp_bar_money/Label # Sarı barın içine eklediğin Label

# --- PARA DEĞİŞKENLERİ ---
@export var max_money: int = 1000
var current_money: int = 400 # Başlangıç parası

func _ready():
	hp_bar_money.max_value = max_money
	update_money_ui()

# --- ARAYÜZ GÜNCELLEME ---
func update_money_ui():
	hp_bar_money.value = current_money
	# Label'a sayıyı "400 / 1000" formatında yazdırıyoruz
	money_label.text = str(current_money) + " / " + str(max_money) 

# --- SEÇİMLERE GÖRE PARA ARTIRMA/AZALTMA ---
func add_money(amount: int):
	current_money = clamp(current_money + amount, 0, max_money)
	update_money_ui()

func remove_money(amount: int):
	current_money = clamp(current_money - amount, 0, max_money)
	update_money_ui()

# --- ÖRNEK OYUNCU SEÇİMLERİ (Eventler/Butonlar) ---

# Oyuncu iyi bir seçim yaptığında veya ödül aldığında bu fonksiyonu çağır:
func on_good_choice_made():
	print("Oyuncu iyi seçim yaptı, para kazandı!")
	add_money(150) # Paraya 150 ekler ve barı/sayıyı günceller

# Oyuncu kötü bir seçim yaptığında veya ceza aldığında bu fonksiyonu çağır:
func on_bad_choice_made():
	print("Oyuncu kötü seçim yaptı, para kaybetti!")
	remove_money(50) # Paradan 50 düşer ve barı/sayıyı günceller
