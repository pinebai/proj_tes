c    "Copyright 2009 Prof. Robert Dalrymple, Prof. M. Gomez Gesteira, Dr Benedict Rogers, 
c     Dr Alejandro Crespo, Dr Muthukumar Narayanaswamy, Dr Shan Zou, Dr Andrea Panizzo "
c
c    This file is part of SPHYSICS.
c
c    SPHYSICS is free software; you can redistribute it and/or modify
c    it under the terms of the GNU General Public License as published by
c    the Free Software Foundation; either version 3 of the License, or
c    (at your option) any later version.
c
c    SPHYSICS is distributed in the hope that it will be useful,
c    but WITHOUT ANY WARRANTY; without even the implied warranty of
c    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
c    GNU General Public License for more details.
c
c    You should have received a copy of the GNU General Public License
c    along with this program.  If not, see <http://www.gnu.org/licenses/>.

      subroutine celij(j1,j2,kind_p1,ini_kind_p2,lx2)
c
      include 'common.2D'  
      
     
      do kind_p2=ini_kind_p2,2
        if(nc(j2,kind_p2).ne.0) then

        do ii=1,nc(j1,kind_p1)
          i = ibox(j1,kind_p1,ii)
         
          do jj=1,nc(j2,kind_p2)
           j = ibox(j2,kind_p2,jj)
            
            drx = xp(i) - xp(j)
            drz = zp(i) - zp(j)

            call periodicityCorrection(i,j,drx,drz,lx2)

            rr2 = drx*drx + drz*drz
            
            if(rr2.lt.fourh2.and.rr2.gt.1.e-18) then
             dux = up(i) - up(j)
             duz = wp(i) - wp(j)


c            Calculating kernel & Normalized Kernel Gradient
             call kernel(drx,drz,i,j,j1,j2,rr2) 
             call kernel_correction(i,j)
               
c            ...  average density

             robar  = 0.5*( rhop(i) + rhop(j) )
             one_over_rhobar = 2.0/(rhop(i) + rhop(j))
c
             cbar = 0.5*( cs(i)   + cs(j)   ) 

c            ...  inner product rv
c
             dot = drx*dux + drz*duz

c            Used to calculate the time step duu to viscosity

             visc_dt=max(dot/(rr2 + eta2),visc_dt) 
c
c            ...  pressure and viscous force (Monaghan 1992; Ann. Rev.
c			        Astron. Astrop. 30. Formula 3.3)
c                 pm(j) is mass of particle j
c
             p_v = pr(i) + pr(j)


             if (index_tensile.eq.1) then

c   ____ Tensile correction 
 
               fab=Wab*od_Wdeltap     !NOTE: We'll use a non-normalized
               fab=fab*fab	          !kernel to calculate tensile correction
               fab=fab*fab            !It's the (Wab/Wdeltap)**4  of Monaghan's paper

               if (p(i).gt.0) then
                  Ra= 0.01 *pr(i)
               else
                  Ra= 0.2 *abs(pr(i))
               endif

               if (p(j).gt.0) then
                  Rb= 0.01 *pr(j)
               else
                  Rb= 0.2 *abs(pr(j))
               endif

               R=Ra+Rb
               p_v = p_v+ R*fab

             endif


            if(i.gt.nb.and.j.gt.nb) then   !both fluid particles

              drho    = rhop(i) - rhop(j)
              drhou   = (Volrhou(i)/pVol(i)) - (Volrhou(j)/pVol(j))
              drhow   = (Volrhow(i)/pVol(i)) - (Volrhow(j)/pVol(j))

              dTotalE = TotalE(i) - TotalE(j)
              
              call approx_RiemannSolver(i,j,drx,drz,rr2,
     &                           drho,drhou,drhow,dTotalE,
     &                           u_a,w_a,rho_a,p_a,TotalE_a,u_0,w_0)

              p_v_x1 = rho_a*u_a*(u_a - u_0) + p_a
              p_v_x2 = rho_a*w_a*(u_a - u_0)
              p_v_z1 = rho_a*u_a*(w_a - w_0)
              p_v_z2 = rho_a*w_a*(w_a - w_0) + p_a
              frx_tmpj = pVol(j)*2.0*frxi
              frz_tmpj = pVol(j)*2.0*frzi
              frx_tmpi = pVol(i)*2.0*frxj
              frz_tmpi = pVol(i)*2.0*frzj
              ax(i) = ax(i) -(p_v_x1*frx_tmpj + p_v_x2*frz_tmpj)
              az(i) = az(i) -(p_v_z1*frx_tmpj + p_v_z2*frz_tmpj)
              ax(j) = ax(j) +(p_v_x1*frx_tmpi + p_v_x2*frz_tmpi)
              az(j) = az(j) +(p_v_z1*frx_tmpi + p_v_z2*frz_tmpi)              
              

              call gradients_calc(i,j,drho,drhou,drhow,dTotalE)                                             

              call viscosity(dot,drx,drz,dux,duz,rr2,
     +               cbar,robar,one_over_rhobar,i,j,j1,j2,term2i,term2j)


c              ...  density acceleration
c              using the derivative of the kernel, not the kernel itself

               dot2ai = (u_a - u_0)*frx_tmpi
     &                + (w_a - w_0)*frz_tmpi
               dot2aj = (u_a - u_0)*frx_tmpj
     &                + (w_a - w_0)*frz_tmpj
               ar(i) = ar(i) - rho_a*dot2aj
               ar(j) = ar(j) + rho_a*dot2ai
               dot2i = dux*frxi + duz*frzi
               dot2j = dux*frxj + duz*frzj
               aVol(i) = aVol(i) - dot2i*pVol(j)
               aVol(j) = aVol(j) - dot2j*pVol(i)

c   ...        Thermal Energy

               aTE(i) = aTE(i) 
     &           - (TotalE_a*dot2aj
     &              + p_a*(u_a*frx_tmpj + w_a*frz_tmpj))
               aTE(j) = aTE(j) 
     &           + (TotalE_a*dot2ai
     &              + p_a*(u_a*frx_tmpi + w_a*frz_tmpi))

c
c              ...  XSPH correction (Monaghan 1994;  J. Comp. Phys. 110. Formula 2.6)
c

               pmj_Wab_over_rhobar = pm(j)*Wab*one_over_rhobar
               ux(i) = ux(i) - dux*pmj_Wab_over_rhobar  !pm(j) * dux * Wab / robar
               wx(i) = wx(i) - duz*pmj_Wab_over_rhobar  !pm(j) * duz * Wab / robar

               pmi_Wab_over_rhobar = pm(i)*Wab*one_over_rhobar
               ux(j) = ux(j) + dux*pmi_Wab_over_rhobar   !pm(i) * dux * Wab / robar
               wx(j) = wx(j) + duz*pmi_Wab_over_rhobar   !pm(i) * duz * Wab / robar

c              ...  Vorticity calculation


             if(ipoute.eq.1.and.i_vort.eq.1.and.i.gt.nb.and.j.gt.nb)then
                  call vorticity_calc(i,j,dux,duz)
             endif  

             else if(i.gt.nb.and.j.le.nb)then			!j is boundary particle
               call MonaghanBC(i,j,drx,drz,dot,dux,duz,
     &                          fxbMON,fzbMON)   

               ax(i) = ax(i) + fxbMON*rhop(i)
               az(i) = az(i) + fzbMON*rhop(i)

               !- Viscous wall force -
c               temp = pVol(i)*visc_wall*
c     &           ((drx*frxi+drz*frzi)/(rr2 + eta2))
c               ax(i) = ax(i) + temp*dux
c               az(i) = az(i) + temp*duz

            
             else if(j.gt.nb.and.i.le.nb)then			!i is boundary particle
               call MonaghanBC(j,i,-drx,-drz,dot,-dux,-duz,
     &                          fxbMON,fzbMON)   

               ax(j) = ax(j) + fxbMON*rhop(j)
               az(j) = az(j) + fzbMON*rhop(j)

               !- Viscous wall force -
c               temp = pVol(j)*visc_wall*
c     &         ((drx*frxj+drz*frzj)/(rr2 + eta2))
c               ax(j) = ax(j) - temp*dux
c               az(j) = az(j) - temp*duz


             endif  ! Interaction fluid-fluid or fluid-boundary  

           endif ! if q<2


         enddo ! Box jj
        enddo ! Box ii
       endif  ! Box jj is not empty
      enddo   ! Kind of particle

      end
