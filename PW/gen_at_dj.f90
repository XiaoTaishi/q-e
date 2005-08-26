!
! Copyright (C) 2002-2003 PWSCF group
! This file is distributed under the terms of the
! GNU General Public License. See the file `License'
! in the root directory of the present distribution,
! or http://www.gnu.org/copyleft/gpl.txt .
!
#include "f_defs.h"
!
!----------------------------------------------------------------------
subroutine gen_at_dj ( kpoint, natw, lmax_wfc, dwfcat )
   !----------------------------------------------------------------------
   !
   ! This routine calculates the atomic wfc generated by the derivative
   ! (with respect to the q vector) of the bessel function. This vector
   ! is needed in computing the internal stress tensor.
   !
   USE kinds,      ONLY : DP
   USE parameters, ONLY : nchix
   USE io_global,  ONLY : stdout
   USE constants,  ONLY : tpi, fpi
   USE atom,       ONLY : msh, r, rab, lchi, nchi, oc, chi
   USE ions_base,  ONLY : nat, ntyp => nsp, ityp, tau
   USE cell_base,  ONLY : omega, at, bg, tpiba
   USE klist,      ONLY : xk
   USE gvect,      ONLY : ig1, ig2, ig3, eigts1, eigts2, eigts3, g
   USE wvfct,      ONLY : npw, npwx, igk
   USE us,         ONLY : tab_at, dq
   !
   implicit none
   !
   !  I/O variables
   !
   integer :: kpoint, natw, lmax_wfc
   complex (kind=DP) :: dwfcat(npwx,natw)
   !
   ! local variables
   !
   integer :: l, na, nt, nb, iatw, iig, i, ig, i0, i1, i2 ,i3, m, lm
   real (kind=DP) :: eps, dv, qt, arg, px, ux, vx, wx
   parameter (eps=1.0e-8)
   complex (kind=DP) :: phase, pref
   real (kind=DP), allocatable :: gk(:,:), q(:), ylm(:,:), djl(:,:,:)
   !          gk(3,npw), q(npw),
   !          ylm(npw,(lmax_wfc+1)**2),
   !          djl(npw,nchix,ntyp)
   complex (kind=DP), allocatable :: sk(:)
   !          sk(npw)

   allocate ( ylm (npw,(lmax_wfc+1)**2) , djl (npw,nchix,ntyp) )
   allocate ( gk(3,npw), q (npw) )

   do ig = 1, npw
      gk (1,ig) = xk(1, kpoint) + g(1, igk(ig) )
      gk (2,ig) = xk(2, kpoint) + g(2, igk(ig) )
      gk (3,ig) = xk(3, kpoint) + g(3, igk(ig) )
      q (ig) = gk(1, ig)**2 +  gk(2, ig)**2 + gk(3, ig)**2
   enddo

   !
   !  ylm = spherical harmonics
   !
   call ylmr2 ((lmax_wfc+1)**2, npw, gk, q, ylm)

   q(:) = dsqrt ( q(:) )

   do nt=1,ntyp
      do nb=1,nchi(nt)
         if (oc(nb,nt) >= 0.d0) then
            l =lchi(nb,nt)
            do ig = 1, npw
               qt=q(ig)*tpiba
               px = qt / dq - int (qt / dq)
               ux = 1.d0 - px
               vx = 2.d0 - px
               wx = 3.d0 - px
               i0 = qt / dq + 1
               i1 = i0 + 1
               i2 = i0 + 2
               i3 = i0 + 3
               djl(ig,nb,nt) = &
                     ( tab_at (i0, nb, nt) * (-vx*wx-ux*wx-ux*vx)/6.d0 + &
                       tab_at (i1, nb, nt) * (+vx*wx-px*wx-px*vx)/2.d0 - &
                       tab_at (i2, nb, nt) * (+ux*wx-px*wx-px*ux)/2.d0 + &
                       tab_at (i3, nb, nt) * (+ux*vx-px*vx-px*ux)/6.d0 )/dq
            enddo
         end if
      end do
   end do
   deallocate ( gk, q )

   allocate ( sk(npw) )

   iatw = 0
   do na=1,nat
      nt=ityp(na)
      arg = ( xk(1,kpoint) * tau(1,na) + &
              xk(2,kpoint) * tau(2,na) + &
              xk(3,kpoint) * tau(3,na) ) * tpi
      phase=CMPLX(cos(arg),-sin(arg))
      do ig =1,npw
         iig = igk(ig)
         sk(ig) = eigts1(ig1(iig),na) *      &
                  eigts2(ig2(iig),na) *      &
                  eigts3(ig3(iig),na) * phase
      end do
      do nb = 1,nchi(nt)
         if (oc(nb,nt) >= 0.d0) then
            l  = lchi(nb,nt)
            pref = (1.d0,0.d0)**l
            pref = (0.d0,1.d0)**l
            do m = 1,2*l+1
               lm = l*l+m
               iatw = iatw+1
               do ig=1,npw
                  dwfcat(ig,iatw)= djl(ig,nb,nt)*sk(ig)*ylm(ig,lm)*pref
               end do
            enddo
         end if
      enddo
   enddo

   if (iatw.ne.natw) then
      WRITE( stdout,*) 'iatw =',iatw,'natw =',natw
      call errore('gen_at_dj','unexpected error',1)
   end if

   deallocate ( sk )
   deallocate ( ylm , djl )

   return
end subroutine gen_at_dj
