#include <xs/xs.h>

/* For compatibility with perl < 5.16 */
#ifndef HvNAMELEN
#define HvNAMELEN(hv) HvNAMELEN_get(hv)
#endif

#define __PACKAGE__ "Panda::Export"
#define EX_CROAK_NOPACKAGE(pack)    croak(__PACKAGE__ ": context package '%" SVf "' doesn't exist", SVfARG(pack))
#define EX_CROAK_NOSUB(hvname,sub)  croak(__PACKAGE__ ": can't export unexisting symbol '%s::%" SVf "'", hvname, SVfARG(sub))
#define EX_CROAK_EXISTS(hvname,sub) croak(__PACKAGE__ ": can't create constant '%s::" SVf "' - symbol already exists", hvname, SVfARG(sub))
#define EX_CROAK_NONAME(hvname)     croak(__PACKAGE__ ": can't define a constant with an empty name in '%s'", hvname)

static AV* get_global_clist (HV* stash) {
    static HV* clists = newHV();
    SV* clist = *hv_fetch(clists, HvNAME(stash), HvNAMELEN(stash), 1);
    AV* ret;
    if (!SvOK(clist)) {
        SvUPGRADE(clist, SVt_RV);
        SvROK_on(clist);
        ret = newAV();
        SvRV_set(clist, (SV*) ret);
    }
    else ret = (AV*) SvRV(clist);
    
    return ret;
}

static inline void create_constant (HV* target, AV* clist, SV* name, SV* value) {
    if (!SvCUR(name)) EX_CROAK_NONAME(HvNAME(target));

    // check that we won't redefine any subroutine
    HE* symentry_he = hv_fetch_ent(target, name, 0, 0);
    if (symentry_he && HeVAL(symentry_he) && isGV(HeVAL(symentry_he)) && GvCV(HeVAL(symentry_he))) EX_CROAK_EXISTS(HvNAME(target), name);
    
    SvREFCNT_inc(value);
    SvREADONLY_on(value);
    newCONSTSUB(target, SvPVX_const(name), value);
    
    av_push(clist, name);
}

static void create_constants_hv (HV* target, HV* constants) {
    HE** hvarr = HvARRAY(constants);
    if (!hvarr) return;
    AV* clist = get_global_clist(target);
    STRLEN hvmax = HvMAX(constants);
    
    for (STRLEN i = 0; i <= hvmax; ++i) {
        const HE* entry;
        for (entry = hvarr[i]; entry; entry = HeNEXT(entry)) {
            HEK* hek = HeKEY_hek(entry);
            create_constant(target, clist, newSVpvn_share(HEK_KEY(hek), HEK_LEN(hek), HEK_HASH(hek)), HeVAL(entry));
        }
    }
}

static void create_constants_list (HV* target, SV** list, I32 items) {
    if (!list || !items) return;
    AV* clist = get_global_clist(target);
    
    for (I32 i = 0; i < items - 1; i += 2) {
        SV* name  = *list++;
        SV* value = *list++;
        if (!name) continue;
        if (SvIsCOW_shared_hash(name)) SvREFCNT_inc_simple_void_NN(name);
        else name = newSVpvn_share(SvPVX_const(name), SvCUR(name), 0);
        create_constant(target, clist, name, value);
    }
}

static void export_subs (HV* from, HV* to, SV** list, SSize_t items) {
    AV* clist = NULL;
    if (!list) {
        clist = get_global_clist(from);
        list = AvARRAY(clist);
        items = AvFILLp(clist)+1;
    }
    
    while (items--) {
        SV* name = *list++;
        const char* name_str = SvPVX_const(name);
        if (name_str[0] == ':' && strEQ(name_str, ":const")) {
            if (!clist) export_subs(from, to, NULL, 0);
            continue;
        }

        HE* symentry_ent = hv_fetch_ent(from, name, 0, 0);
        GV* symentry = symentry_ent ? (GV*)HeVAL(symentry_ent) : NULL;
        if (!symentry || !GvCV(symentry)) EX_CROAK_NOSUB(HvNAME(from), name);
        
        SvREFCNT_inc_simple_void_NN((SV*)symentry);
        hv_store_ent(to, name, (SV*)symentry, 0);
    }
}


MODULE = Panda::Export                PACKAGE = Panda::Export
PROTOTYPES: DISABLE

void import (SV* ctx_class, ...) {
    HV* caller_stash = CopSTASH(PL_curcop);
    if (strEQ(SvPV_nolen(ctx_class), __PACKAGE__)) {
        if (items < 2) XSRETURN(0);
        SV* arg = ST(1);
        if (SvROK(arg) && SvTYPE(SvRV(arg)) == SVt_PVHV) create_constants_hv(caller_stash, (HV*) SvRV(arg));
        else create_constants_list(caller_stash, &ST(1), items-1);
    }
    else {
        HV* ctx_stash = gv_stashsv(ctx_class, 0);
        if (ctx_stash == NULL) EX_CROAK_NOPACKAGE(ctx_class);
        export_subs(ctx_stash, caller_stash, items > 1 ? &ST(1) : NULL, items-1);
    }
}    

SV* constants_list (SV* ctx_class) {
    HV* ctx_stash = gv_stashsv(ctx_class, 0);
    if (ctx_stash == NULL) EX_CROAK_NOPACKAGE(ctx_class);
    RETVAL = newRV((SV*) get_global_clist(ctx_stash));
}    
