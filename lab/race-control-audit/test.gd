extends SceneTree
const A=preload("res://audit.gd")
var checks:int=0
var failures:Array[String]=[]
func ck(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures.append(label);printerr("FAIL ",label)
func _initialize()->void:
	var ends:Array=[100000,200000,300000]
	var speeds:Array=[50000,40000,50000]
	ck(A.sector_session(0,300000,[200000,100000,300000],speeds).is_empty(),"invalid geometry")
	var x:Dictionary=A.sector_session(90000,300000,ends,speeds)
	ck(A.sector_tick(x,90000,100000,0,true).is_empty(),"partial sector excluded")
	var observations:Array=[]
	var distance:int=100000
	for tick in range(1,22):
		var next:int=distance+10000
		observations.append_array(A.sector_tick(x,distance,next,tick,true));distance=next
	ck(observations.size()==2,"two complete sectors")
	ck(int(observations[0].delta_us)==-500000,"early sector delta")
	ck(int(observations[1].delta_us)==0,"reference pace after seam")
	ck(A.review(observations[0]).status=="REVIEW","single warning not confirmed")
	ck(A.review(observations[1]).status=="DISMISSED","within tolerance")
	var evidence:Dictionary=observations[0].duplicate();evidence.fast_streak=2
	ck(A.review(evidence).status=="CONFIRMED" and A.review(evidence).penalty_ms==0,"repeated evidence, no automatic penalty")
	evidence.exempt=true;ck(A.review(evidence).status=="DISMISSED","exemption")
	evidence.exempt=false;evidence.delta_us=10;ck(A.review(evidence).status=="INCONCLUSIVE","invalid evidence")
	ck(A.review({"kind":"order_warning"}).status=="INCONCLUSIVE","crossing not automatically guilty")
	A.sector_tick(x,distance,distance+10000,22,false)
	ck(int(x.last_us)==-1 and int(x.fast_streak)==0,"exempt reset")
	var a:Dictionary={"s0":0,"s1":12000,"d0":0,"d1":0,"length":5000,"width":1800}
	var b:Dictionary={"s0":8000,"s1":8000,"d0":0,"d1":0,"length":5000,"width":1800}
	ck(A.swept_contact(a,b,300000).contact,"rear swept contact")
	ck(A.swept_contact(b,a,300000).contact,"pair symmetry")
	b.d0=2500;b.d1=2500;ck(not A.swept_contact(a,b,300000).contact,"parallel corridors clear")
	b.d0=2500;b.d1=0;ck(A.swept_contact(a,b,300000).contact,"lateral sweep")
	a.s0=294000;a.s1=306000;b.s0=301000;b.s1=301000;b.d0=0;b.d1=0
	ck(A.swept_contact(a,b,300000).contact,"finish line seam")
	b.s0=601000;b.s1=601000;ck(A.swept_contact(a,b,300000).contact,"lapped body proximity")
	b.s0=450000;b.s1=450000;ck(not A.swept_contact(a,b,300000).contact,"half lap clear")
	print("APEX_AUDIT_LAB ",JSON.stringify({"checks":checks,"failures":failures,"status":"PASS" if failures.is_empty() else "FAIL"}))
	quit(0 if failures.is_empty() else 1)
