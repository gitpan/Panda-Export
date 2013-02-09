#ifdef __cplusplus
extern "C" {
#endif
#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"
#ifdef __cplusplus
}
#endif

#include "ppport.h"

/* For compatibility with perl < 5.16 */
#ifndef HvNAMELEN
#define HvNAMELEN(hv) HvNAMELEN_get(hv)
#endif

#define __PACKAGE__ "Panda::Export"

AV* get_global_clist (HV* stash) {
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

void create_constants (HV* target, HV* constants) {
    AV* clist = get_global_clist(target);
    
    I32 size = hv_iterinit(constants);
    for (I32 i = 0; i < size; i++) {
        HE* pair = hv_iternext(constants);
        char* key = HeKEY(pair);
        I32 klen = HeKLEN(pair);
        if (klen == 0) croak("Panda::Export: found constant with empty name");

        // check that we won't redefine any subroutine
        SV** symentry = hv_fetch(target, key, klen, 0);
        if (symentry != NULL && GvCV((GV*)*symentry) != NULL) croak(
            "Panda::Export: cannot create constant - %s '%s' already exists in package '%s'",
            gv_const_sv((GV*)*symentry) == NULL ? "function" : "constant", key, HvNAME(target)
        );
        
        SV* value = HeVAL(pair);
        SvREFCNT_inc(value);
        SvREADONLY_on(value);
        newCONSTSUB(target, key, value);
        
        av_push(clist, newSVpv(key, klen));
    }
}

void export_subs (HV* from, HV* to, AV* list) {
    if (list != NULL) {
        I32 size = av_len(list);
        for (I32 i = 0; i <= size; i++) {
            SV* nameSV = *av_fetch(list, i, 0);
            STRLEN namelen;
            const char* name = SvPV(nameSV, namelen);
            if (strEQ(name, ":const")) {
                export_subs(from, to, get_global_clist(from));
                continue;
            }

            SV** symentry_ref = hv_fetch(from, name, namelen, 0);
            GV* symentry = symentry_ref == NULL ? NULL : (GV*)*symentry_ref;
            if (symentry == NULL || !GvCV(symentry)) croak(
                "Panda::Export: cannot export function '%s' - it doesn't exist in package '%s'",
                name, HvNAME(from)
            );
            
            SvREFCNT_inc((SV*) symentry);
            hv_store(to, name, namelen, (SV*) symentry, 0);
        }
    }
    else export_subs(from, to, get_global_clist(from));
}


MODULE = Panda::Export                PACKAGE = Panda::Export
PROTOTYPES: DISABLE

void
import (const char* ctx_class, ...)
PPCODE:
    HV* caller_stash = CopSTASH(PL_curcop);
    if (strEQ(ctx_class, __PACKAGE__)) {
        if (items < 2) XSRETURN(0);
        SV* arg = ST(1);
        if (SvOK(arg) && SvROK(arg) && SvTYPE(SvRV(arg)) == SVt_PVHV)
            create_constants(caller_stash, (HV*) SvRV(arg));
    }
    else {
        AV* list = NULL;
        if (items >= 2) {
            list = newAV();
            for (int i = 1; i < items; i++) {
                SV* name = ST(i);
                SvREFCNT_inc(name);
                av_push(list, name);
            }
        }
        HV* ctx_stash = gv_stashpv(ctx_class, 0);
        if (ctx_stash == NULL) croak("Panda::Export: context package %s does not exist", ctx_class);
        export_subs(ctx_stash, caller_stash, list);
        if (list != NULL) SvREFCNT_dec(list);
    }
    
    XSRETURN(0);
    

SV*
constants_list (const char* ctx_class)
CODE:
    HV* ctx_stash = gv_stashpv(ctx_class, 0);
    if (ctx_stash == NULL) croak("Panda::Export: context package %s does not exist", ctx_class);
    RETVAL = newRV((SV*) get_global_clist(ctx_stash));
OUTPUT:
    RETVAL
    
