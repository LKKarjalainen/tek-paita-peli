extends DigOutMinigame
## Kaiva hallituksen kaappi tyhjäksi.
##
## Everything a board accumulates except the one thing being looked for. The
## last item out is shirt-shaped and shirt-coloured, and is a pillowcase.


func configure() -> void:
	task_title = "HALLITUS KAAPPI"
	closing_line = "Ei paitaa. VITTU"
	contents = [
		"haalarimerkit2",
		"Kassakaappi",
		"haalarimerkit",
		"jaloviina",
		"marskiryyppy",
	]
