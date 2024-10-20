/obj/structure/closet/secure_closet/nanotrasen_representative
	name = "nanotrasen representative's locker"
	req_access = list(ACCESS_CENT_GENERAL)
	icon_state = "cc"
	icon = 'monkestation/code/modules/blueshift/icons/obj/closet.dmi'

obj/structure/closet/secure_closet/nanotrasen_representative/PopulateContents()
	..()
	new /obj/item/storage/backpack/satchel/leather(src)
	new /obj/item/computer_disk/command/captain(src)
	new /obj/item/storage/photo_album/personal(src)
	new /obj/item/bedsheet/centcom(src)
	new /obj/item/storage/bag/garment/nanotrasen_representative(src)
	new /obj/item/storage/bag/garment/stolen(src)
