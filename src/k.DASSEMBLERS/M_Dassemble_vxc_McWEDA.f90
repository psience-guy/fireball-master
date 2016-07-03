! copyright info:
!
!                             @Copyright 2016
!                           Fireball Committee
! West Virginia University - James P. Lewis, Chair
! Arizona State University - Otto F. Sankey
! Universidad Autonoma de Madrid - Jose Ortega
! Academy of Sciences of the Czech Republic - Pavel Jelinek

! Previous and/or current contributors:
! Auburn University - Jian Jun Dong
! Caltech - Brandon Keith
! Dublin Institute of Technology - Barry Haycock
! Pacific Northwest National Laboratory - Kurt Glaesemann
! University of Texas at Austin - Alex Demkov
! Ohio University - Dave Drabold
! Washington University - Pete Fedders
! West Virginia University - Ning Ma and Hao Wang
! also Gary Adams, Juergen Frisch, John Tomfohr, Kevin Schmidt,
!      and Spencer Shellman
!
! RESTRICTED RIGHTS LEGEND
! Use, duplication, or disclosure of this software and its documentation
! by the Government is subject to restrictions as set forth in subdivision
! { (b) (3) (ii) } of the Rights in Technical Data and Computer Software
! clause at 52.227-7013.

! M_Dassemble_vxc
! Module Description
! ===========================================================================
!>       This is a module containing all of the  programs required
!! to assemble all the deriatives of the matrix elements for exchange-correlation -
!! see PRB 71, 235101 (2005).
!!
!! It contains the following subroutines within the module:
!!
!!       Dassemble_vxc : XC-main  program. Driver
!!       Dassemble_vxc_SN : assembles the generalized Sankey-Niklewski both for
!!
!!               rho_in (input density) --> (vxc_SN)
!!           and
!!               rho_bond (local or "atomic" (_at) density) --> vxc_SN_bond
!!
!! Definition of rho_in and rho_local:
!!       rho_bond (mu,nu) = < mu | rho_i | nu >
!!         if mu and nu are in the same atom "i" : onsite case
!!       rho_bond (mu,nu) = < mu | rho_i + rho_j | nu >
!!         if mu and nu are in different atoms "i" and "j" : atom case
!!       rho_in = sum of onsite rho_bond values
!!
!!       Dassemble_vxc_bond : assembles the derivative XC-potential matrix elements
!!
!!           d (vxc_bond (mu,nu)/dR =  d (< mu | V_xc(rho_i + rho_j) | nu >)/dR
!!
!!      Dassemble_vxc_3c : assmebles the derivatives for the three center interactions
!!                         of the XC-potential matrix elements
!
! For a complete list of the interactions see the files 2c.Z1.Z2.dir now
! located in the Fdata directory.  This list will change depending on
! the datafiles included there. This list is an output from running create.x
! ===========================================================================
        module M_Dassemble_vxc
        use M_assemble_blocks
        use M_configuraciones
        use M_assemble_vxc
        use M_Dassemble_rho_McWEDA
        use M_Dassemble_2c !**


! Type Declaration
! ===========================================================================

! module procedures
        contains

! ===========================================================================
! Dassemble_vxc.f90
! ===========================================================================
! Subroutine Description
! ===========================================================================
!>  This is the main module for assembling the derivatires of the Vxc matrix elements
!! interactions (McWEDA). The results are stored in vxc (potential) Dblok part.
! ===========================================================================
! Code written by:
!> @author Daniel G. Trabada
!! @author Jose Ortega (JOM)
! Departamento de Fisica Teorica de la Materia Condensada
! Universidad Autonoma de Madrid
! ===========================================================================
!
! Program Declaration
! ===========================================================================
        subroutine Dassemble_vxc (s)
        implicit none

! Argument Declaration and Description
! ===========================================================================
        type(T_structure), target :: s           !< the structure to be used.

! Parameters and Data Declaration
! ===========================================================================
! None

! Variable Declaration and Description
! ===========================================================================
        integer iatom, ineigh, matom       !< counter over atoms and neighbors
        integer in1, in2                   !< species numbers
        integer jatom                      !< neighbor of iatom
        integer logfile                    !< writing to which unit
        integer num_neigh                  !< number of neighbors

        integer norb_mu, norb_nu           !< size of the block for the pair

        type(T_assemble_block), pointer :: pvxc_neighbors
        type(T_assemble_neighbors), pointer :: pvxc

! Allocate Arrays
! ===========================================================================


! Procedure
! ===========================================================================
! Initialize logfile
        logfile = s%logfile

! Calculate rho_in (density) matrix elements
        write (logfile,*) ' Calling rho (density) input assemblers. '

! calculate  derivatires for average_rho matrix elements
! See Review OSLXC method
        call Dassemble_rho_2c (s)
        call Dassemble_rho_weighted_2c (s)
        call Dassemble_rho_3c (s)
        call Dassemble_rho_weighted_3c (s)

! calculate derivatives of XC-potential matrix elements
        write (logfile,*) ' Calling vxc assemblers. '

! Calculate the derivativies of the matrix elements
        ! this term has the 2 center SNXC part and the OLSXC part too
        call Dassemble_vxc_SN (s)
        ! this term has the d(<mu_i|vxc(rho_ij)|nu_j>)/dR part
        call Dassemble_vxc_bond (s)

! (3) Sum all three contributions :
        do iatom = 1, s%natoms
          ! cut some lengthy notation
          pvxc=>s%vxc(iatom)
          in1 = s%atom(iatom)%imass
          norb_mu = species(in1)%norb_max
          num_neigh = s%neighbors(iatom)%neighn
          matom = s%neigh_self(iatom)
! Loop over the neighbors of each iatom.
          do ineigh = 1, num_neigh  ! <==== loop over i's neighbors
            ! cut some more lengthy notation
            pvxc_neighbors=>pvxc%neighbors(ineigh)
            jatom = s%neighbors(iatom)%neigh_j(ineigh)
            in2 = s%atom(jatom)%imass
            norb_nu = species(in2)%norb_max
            allocate (pvxc_neighbors%Dblock(3,norb_mu, norb_nu))
            allocate (pvxc_neighbors%Dblocko(3,norb_mu, norb_mu))

! additions of the terms
            pvxc_neighbors%Dblock = vxc_SN(iatom)%neighbors(ineigh)%Dblock +   &
     &             vxc_SN_bond(iatom)%neighbors(ineigh)%Dblock +               &
     &             vxc_bond(iatom)%neighbors(ineigh)%Dblock

            pvxc_neighbors%Dblocko = vxc_SN(iatom)%neighbors(matom)%Dblocko    &
     &                              + vxc_SN_bond(iatom)%neighbors(matom)%Dblocko
          end do ! loop over neighbors
        end do ! loop over atoms

! Deallocate Arrays
! ===========================================================================
! None

! Format Statements
! ===========================================================================
! None

! End Subroutine
! ===========================================================================
        return
        end subroutine Dassemble_vxc


! ===========================================================================
! Dassemble_vxc_SN
! ===========================================================================
! Subroutine Description
! ===========================================================================
!>       This routine calculates/assembles the SNXC 2 center part, the OLSXC 2
!!       center part, and also the d (< mu_i| V_xc (rho) | nu_i>)/dR called
!!       "on-site" in the notes.
!!
!!               rho_in (input density) --> (vxc_SN)
!!       and
!!               rho_bond (local or "atomic" (_at) density) --> vxc_SN_bond
!!
!! Definition of rho_in and rho_local:
!!       rho_bond (mu,nu) = < mu | rho_i | nu >
!!         if mu and nu are in the same atom "i" : onsite case
!!       rho_bond (mu,nu) = < mu | rho_i + rho_j | nu >
!!         if mu and nu are in different atoms "i" and "j" : atom case
!!       rho_in = sum of onsite rho_bond values
!
! ===========================================================================
! Code written by:
!> @author Daniel G. Trabada
!! @author Jose Ortega (JOM)
! Departamento de Fisica Teorica de la Materia Condensada
! Universidad Autonoma de Madrid
! ===========================================================================
!
! Program Declaration
! ===========================================================================
        subroutine Dassemble_vxc_SN (s)
        implicit none

! Argument Declaration and Description
! ===========================================================================
        type(T_structure), target :: s           !< the structure to be used.

! Parameters and Data Declaration
! ===========================================================================
! None

! Variable Declaration and Description
! ===========================================================================
        integer iatom, ineigh!, mneigh      !< counter over atoms and neighbors
        integer in1, in2!, in3              !< species numbers
        integer jatom!, ialpha              !< jatom is the neighbor of iatom ialpha is the third atom for 3c
        integer logfile                    !< writing to which unit
        integer num_neigh                  !< number of neighbors
        integer matom                      !< matom is the self-interaction atom
        integer mbeta                      !< the cell containing neighbor of iatom

        integer imu, inu                   !< counter over orbitals
        integer issh, jssh                 !< counter over shells
        integer n1, n2, l1, l2, m1, m2     !< quantum numbers n, l, and m
        integer norb_mu, norb_nu           !< size of the block for the pair

        ! inputs for xc functional
        real prho_in_shell               !< temporary storage
        real prho_bond_shell             !< temporary storage
        real poverlap                    !< temporary stroage
        real prho_in                     !< temporary storage
        real prho_bond                   !< temporary storage
        real dexc_in, dexc_bond          !< 1st derivative of xc energy
        real d2exc_in, d2exc_bond        !< 2nd derivative of xc energy
        real dmuxc_in, dmuxc_bond        !< 1st derivative of xc potential
        real exc_in, exc_bond            !< xc energy
        real muxc_in, muxc_bond          !< xc potential_
        real d2muxc_in, d2muxc_bond      !< 2nd derivative of xc potential
        real delta

        real, dimension (3) :: r1, r2      !< positions of iatom and jatom ialpha

        ! vector derivatives of rho pieces
        real, dimension (3) :: Dprho_in_weighted
        real, dimension (3) :: Dprho_in
        real, dimension (3) :: Dprho_bond_weighted
        real, dimension (3) :: Dprho_bond
        real, dimension (3) :: Dpoverlap

        type(T_assemble_block), pointer :: pvxc_SN_neighbors
        type(T_assemble_neighbors), pointer :: pvxc_SN
        type(T_assemble_block), pointer :: pvxc_SN_bond_neighbors
        type(T_assemble_neighbors), pointer :: pvxc_SN_bond

! Allocate Arrays
! ===========================================================================
! None

! Procedure
! ===========================================================================
! Initialize logfile
        logfile = s%logfile

! Procedure
! ===========================================================================
! ***************************************************************************
!
!                       O F F  -  S I T E    P I E C E(off diagonal terms)
!
! ***************************************************************************
! Loop over the atoms in the central cell.
        do iatom = 1, s%natoms
          ! cut some lengthy notation
          pvxc_SN=>vxc_SN(iatom)
          pvxc_SN_bond=>vxc_SN_bond(iatom)
          in1 = s%atom(iatom)%imass
          matom = s%neigh_self(iatom) !**
          r1 = s%atom(iatom)%ratom !**
          norb_mu = species(in1)%norb_max
          num_neigh = s%neighbors(iatom)%neighn

! Loop over the neighbors of each iatom.
          do ineigh = 1, num_neigh  ! <==== loop over i's neighbors
            ! cut some more lengthy notation
            pvxc_SN_neighbors=>pvxc_SN%neighbors(ineigh) !** matom sefl
            pvxc_SN_bond_neighbors=>pvxc_SN_bond%neighbors(ineigh)
            mbeta = s%neighbors(iatom)%neigh_b(ineigh)
            jatom = s%neighbors(iatom)%neigh_j(ineigh)
            r2 = s%atom(jatom)%ratom + s%xl(mbeta)%a
            in2 = s%atom(jatom)%imass
            norb_nu = species(in2)%norb_max
            allocate (pvxc_SN_neighbors%Dblock(3,norb_mu, norb_nu))
            allocate (pvxc_SN_bond_neighbors%Dblock(3,norb_mu, norb_nu))
            pvxc_SN_neighbors%Dblock= 0.0d0
            pvxc_SN_bond_neighbors%Dblock= 0.0d0

! If r1 .eq. r2, then this is a case of a seslf-interaction or "on-site" term;
! therefore, we do not calculate here.
            if (iatom .eq. jatom .and. mbeta .eq. 0) then

! Do nothing here - special case. Interaction already calculated in "on-site" case.
            else
              n1 = 0
              do issh = 1, species(in1)%nssh
! n1 : counter used to determine orbitals imu
                l1 = species(in1)%shell(issh)%lssh
                n1 = n1 + l1 + 1
! Loop over shells ineigh
                n2 = 0
                do jssh = 1, species(in2)%nssh
! n2 : counter used to determine orbitals inu
                   l2 = species(in2)%shell(jssh)%lssh
                   n2 = n2 + l2 + 1
! Call lda-function with rho_in_weighted to get the coefficients for vxc expancion
                   prho_in_shell =                                           &
                    s%rho_in_weighted(iatom)%neighbors(ineigh)%block(issh,jssh)
                   call lda_ceperley_alder (prho_in_shell, exc_in, muxc_in,  &
     &                                      dexc_in, d2exc_in, dmuxc_in, d2muxc_in)

! Call lda-function with rho_bon_weighted to get the coefficients for vxc expancion
                   prho_bond_shell =                                         &
     &              s%rho_bond_weighted(iatom)%neighbors(ineigh)%block(issh,jssh)
                   call lda_ceperley_alder (prho_bond_shell, exc_bond, muxc_bond, &
     &                                      dexc_bond, d2exc_bond, dmuxc_bond, d2muxc_bond)

! loop over orbitals in the iatom-shell (imu)
                   do m1 = -l1, l1
                     imu = n1 + m1
! loop over orbitals in the ineigh-shell (inu)
                     do m2 = -l2, l2
                       inu = n2 + m2
! terms needed to build up the SNXC 2 center and OLSXC 2 center parts
                       poverlap=                                             &
     &                   s%overlap(iatom)%neighbors(ineigh)%block(imu,inu)
                       Dpoverlap(:)=                                         &
     &                   s%overlap(iatom)%neighbors(ineigh)%Dblock(:,imu,inu)

                       prho_in=                                              &
     &                   s%rho_in(iatom)%neighbors(ineigh)%block(imu,inu)
                       Dprho_in_weighted=                                    &
     &                   s%rho_in_weighted(iatom)%neighbors(ineigh)%Dblock(:,issh,jssh)

                       Dprho_in=                                             &
     &                   s%rho_in(iatom)%neighbors(ineigh)%Dblock(:,imu,inu)
                       prho_bond=                                            &
     &                   s%rho_bond(iatom)%neighbors(ineigh)%block(imu,inu)

                       Dprho_bond_weighted(:)=                               &
     &                   s%rho_bond_weighted(iatom)%neighbors(ineigh)%Dblock(:,issh,jssh)

                       Dprho_bond(:)=                                        &
     &                   s%rho_bond(iatom)%neighbors(ineigh)%Dblock(:,imu,inu)

                       ! This is the SNXC 2 center part
                       pvxc_SN_neighbors%Dblock(:,imu,inu) =                 &
     &                   pvxc_SN_neighbors%Dblock(:,imu,inu)                 &
     &                   + Dpoverlap*(muxc_in - dmuxc_in*prho_in_shell)      &
     &                   + Dprho_in_weighted*d2muxc_in*(prho_in - prho_in_shell*poverlap)&
     &                   + dmuxc_in*Dprho_in

                       ! This is the OLSXC 2 center part
                       pvxc_SN_bond_neighbors%Dblock(:,imu,inu) =            &
     &                   pvxc_SN_bond_neighbors%Dblock(:,imu,inu)            &
     &                   - Dpoverlap*(muxc_bond - dmuxc_bond*prho_bond_shell)&
     &                   - Dprho_bond_weighted*d2muxc_bond*(prho_bond - prho_bond_shell*poverlap)&
     &                   - dmuxc_bond*Dprho_bond

                       if (iatom .eq. jatom) then
                         delta = 0
                         if (imu .eq. inu) then
                           delta = 1
                         end if
                         ! This is the so called "on-site" term it is putted here the density
                         pvxc_SN_neighbors%Dblock(:,imu,inu) =               &
     &                    - delta*d2muxc_in*prho_in_shell*Dprho_in_weighted  &
     &                    + dmuxc_in*Dprho_in                                &
     &                    + prho_in*Dprho_in_weighted*d2muxc_in
                       end if
                     end do !** m2 = -l2, l2
                   end do !** m1 = -l1, l1
                end do !** jssh = 1, species(in2)%nssh
              end do !** issh = 1, species(in1)%nssh
            end if !** differenciate between on site and off site
          end do !** over the neighbors
        end do !** over the atoms

! ***************************************************************************
!
!                       O N  -  S I T E    P I E C E (diagonal terms)
!
! ***************************************************************************
! Loop over the atoms in the central cell.
        do iatom = 1, s%natoms
          ! cut some lengthy notation
          pvxc_SN=>vxc_SN(iatom)
          pvxc_SN_bond=>vxc_SN_bond(iatom)
          matom = s%neigh_self(iatom)
          in1 = s%atom(iatom)%imass
          norb_mu = species(in1)%norb_max
          num_neigh = s%neighbors(iatom)%neighn

          ! cut some more lengthy notation
          pvxc_SN_neighbors=>pvxc_SN%neighbors(matom)
          pvxc_SN_bond_neighbors=>pvxc_SN_bond%neighbors(matom)
          norb_nu = species(in1)%norb_max
          allocate (pvxc_SN_neighbors%Dblocko(3,norb_mu, norb_nu))
          allocate (pvxc_SN_bond_neighbors%Dblocko(3,norb_mu, norb_nu))
          pvxc_SN_neighbors%Dblocko= 0.0d0
          pvxc_SN_bond_neighbors%Dblocko= 0.0d0

! SPECIAL LOOP: we want to minimize the number of calls to lda-function
! we only need to call lda_ceperley-adler for each pair of shells
! but then we need to calculate the (mu,nu)-block of matrix elements

! Loop over shells i-atom
          n1 = 0
          do issh = 1, species(in1)%nssh
! n1 : counter used to determine orbitals imu
            l1 = species(in1)%shell(issh)%lssh
            n1 = n1 + l1 + 1
! Call lda-function for rho_in
            prho_in_shell =                                                  &
     &        s%rho_in_weighted(iatom)%neighbors(matom)%block(issh,issh)
            call lda_ceperley_alder (prho_in_shell, exc_in, muxc_in,         &
     &                                 dexc_in, d2exc_in, dmuxc_in, d2muxc_in)

            prho_bond_shell =                                                &
     &        s%rho_bond_weighted(iatom)%neighbors(matom)%block(issh,issh)
            call lda_ceperley_alder (prho_bond_shell, exc_bond, muxc_bond,   &
     &                               dexc_bond, d2exc_bond, dmuxc_bond, d2muxc_bond)

! Calculate vxc_SN and vxc_SN_bond for (mu,nu)-block
! loop over orbitals in the iatom-shell (imu)
            do m1 = -l1, l1
              imu = n1 + m1
              prho_in =                                                      &
     &          s%rho_in(iatom)%neighbors(matom)%block(imu,imu)
              Dprho_in =                                                     &
     &          s%rho_in(iatom)%neighbors(matom)%Dblock(:,imu,imu)
              Dprho_in_weighted =                                            &
     &          s%rho_in_weighted(iatom)%neighbors(matom)%Dblock(:,issh,issh)

              prho_bond=                                                     &
     &          s%rho_bond(iatom)%neighbors(matom)%block(imu,imu)
              Dprho_bond(:)=                                                 &
     &          s%rho_bond(iatom)%neighbors(matom)%Dblock(:,imu,imu)
              Dprho_bond_weighted(:)=                                        &
     &          s%rho_bond_weighted(iatom)%neighbors(matom)%Dblock(:,issh,issh)


! calculate GSN for rho_in
              pvxc_SN_neighbors%Dblocko(:,imu,imu)=                          &
     &          dmuxc_in*Dprho_in_weighted                                   &
     &          + Dprho_in_weighted*d2muxc_in*(prho_in -prho_in_shell)       &
     &          + dmuxc_in*(Dprho_in - Dprho_in_weighted)

              pvxc_SN_bond_neighbors%Dblocko(:,imu,imu) =                    &
     &          dmuxc_bond*Dprho_bond_weighted                               &
     &          + Dprho_bond_weighted*d2muxc_bond*(prho_bond -prho_bond_shell) &
     &          + dmuxc_bond*(Dprho_bond - Dprho_bond_weighted)
            end do ! m1 = -l1, l1

! Loop over shells ineigh
            n2 = 0
            do jssh = 1, species(in1)%nssh
! n2 : counter used to determine orbitals inu
              l2 = species(in1)%shell(jssh)%lssh
              n2 = n2 + l2 + 1

! Call lda-function for rho_in
              prho_in_shell =                                                  &
     &          s%rho_in_weighted(iatom)%neighbors(matom)%block(issh,jssh)
              call lda_ceperley_alder (prho_in_shell, exc_in, muxc_in,         &
     &                                 dexc_in, d2exc_in, dmuxc_in, d2muxc_in)

              prho_bond_shell =                                                &
     &          s%rho_bond_weighted(iatom)%neighbors(matom)%block(issh,jssh)
              call lda_ceperley_alder (prho_bond_shell, exc_bond, muxc_bond,   &
     &                                 dexc_bond, d2exc_bond, dmuxc_bond, d2muxc_bond)

! Calculate vxc_SN and vxc_SN_bond for (mu,nu)-block
! loop over orbitals in the iatom-shell (imu)
              do m1 = -l1, l1
                imu = n1 + m1
! loop over orbitals in the ineigh-shell (inu)
                do m2 = -l2, l2
                  inu = n2 + m2
                  if (imu .ne. inu) then
                    prho_in=                                                   &
     &                s%rho_in(iatom)%neighbors(matom)%block(imu,inu)
                    Dprho_in=                                                  &
     &                s%rho_in(iatom)%neighbors(matom)%Dblock(:,imu,inu)
                    Dprho_in_weighted=                                         &
     &                s%rho_in_weighted(iatom)%neighbors(matom)%Dblock(:,issh,jssh)

                    prho_bond=                                                 &
     &                s%rho_bond(iatom)%neighbors(matom)%block(imu,inu)
                    Dprho_bond(:)=                                             &
                      s%rho_bond(iatom)%neighbors(matom)%Dblock(:,imu,inu)
                    Dprho_bond_weighted(:)=                                    &
     &                s%rho_bond_weighted(iatom)%neighbors(matom)%Dblock(:,issh,jssh)

! calculate GSN for rho_in
                    pvxc_SN_neighbors%Dblocko(:,imu,inu)=                      &
     &                Dprho_in_weighted*d2muxc_in*prho_in + dmuxc_in*Dprho_in
                    pvxc_SN_bond_neighbors%Dblocko(:,imu,inu)=                 &
     &                Dprho_bond_weighted*d2muxc_bond*prho_bond + dmuxc_bond*Dprho_bond
                  end if ! imu .eq. inu
                end do !do m2 = -l2, l2
              end do !do m1 = -l1, l1
              n2 = n2 + l2
            end do  ! do jssh = 1, nssh(in1)
            n1 = n1 + l1
          end do  ! do issh = 1, nssh(in1)
        end do ! end loop over atoms

! Deallocate Arrays
! ===========================================================================
! None

! Format Statements
! ===========================================================================
! None

! End Subroutine
! ===========================================================================
        return
        end subroutine Dassemble_vxc_SN


! ===========================================================================
! Dassemble_vxc_bond.f90
! ===========================================================================
! Subroutine Description
! ===========================================================================
!>       Dassemble_vxc_bond : assembles the derivative XC-potential matrix elements
!!
!!           d (vxc_bond (mu,nu)/dR =  d (< mu | V_xc(rho_i + rho_j) | nu >)/dR
!
! ===========================================================================
! Code written by:
!> @author Daniel G. Trabada
!! @author Jose Ortega (JOM)
! Departamento de Fisica Teorica de la Materia Condensada
! Universidad Autonoma de Madrid
! ===========================================================================
!
! Program Declaration
! ===========================================================================
        subroutine Dassemble_vxc_bond (s)
        implicit none

! Argument Declaration and Description
! ===========================================================================
        type(T_structure), target :: s           !< the structure to be used.

! Parameters and Data Declaration
! ===========================================================================
! None

! Variable Declaration and Description
! ===========================================================================
        integer iatom, ineigh            !< counter over atoms and neighbors
        integer in1, in2, in3            !< species numbers
        integer jatom                    !< neighbor of iatom
        integer interaction, isubtype    !< which interaction and subtype
        integer num_neigh                !< number of neighbors
        integer mbeta                    !< the cell containing iatom's neighbor

        integer imu, inu
        integer norb_mu, norb_nu         !< size of the block for the pair

        real z                           !< distance between r1 and r2
        real, dimension (3) :: eta        !< vector part of epsilon eps(:,3)
        real, dimension (3, 3, 3) :: deps !< derivative of epsilon matrix
        real, dimension (3, 3) :: eps    !< the epsilon matrix
        real, dimension (3) :: r1, r2    !< positions of iatom and jatom
        real, dimension (3) :: sighat    !< unit vector along r2 - r1

        real, dimension (:, :), allocatable :: bcxcm
        real, dimension (:, :), allocatable :: bcxcx
        real, dimension (:, :), allocatable :: dbcxcm
        real, dimension (:, :, :), allocatable :: vdcxcm
        real, dimension (:, :, :), allocatable :: vdbcxcx

        interface
          function distance (a, b)
            real distance
            real, intent (in), dimension (3) :: a, b
          end function distance
        end interface

        type(T_assemble_block), pointer :: pvxc_bond_neighbors
        type(T_assemble_neighbors), pointer :: pvxc_bond

! Allocate Arrays
! ===========================================================================
! None

! Procedure
! ===========================================================================
! Loop over the atoms in the central cell.
        do iatom = 1, s%natoms
          ! cut some lengthy notation
          pvxc_bond=>vxc_bond(iatom)
          r1 = s%atom(iatom)%ratom
          in1 = s%atom(iatom)%imass
          norb_mu = species(in1)%norb_max
          num_neigh = s%neighbors(iatom)%neighn
          allocate (pvxc_bond%neighbors(num_neigh))

! Loop over the neighbors of each iatom.
          do ineigh = 1, num_neigh  ! <==== loop over i's neighbors
            ! cut some more lengthy notation
            pvxc_bond_neighbors=>pvxc_bond%neighbors(ineigh)
            mbeta = s%neighbors(iatom)%neigh_b(ineigh)
            jatom = s%neighbors(iatom)%neigh_j(ineigh)
            r2 = s%atom(jatom)%ratom + s%xl(mbeta)%a
            in2 = s%atom(jatom)%imass

! Allocate block size
            norb_nu = species(in2)%norb_max
            allocate (pvxc_bond_neighbors%Dblock(3, norb_mu, norb_nu))
            pvxc_bond_neighbors%Dblock = 0.0d0

! SET-UP STUFF
! ****************************************************************************
! Find r21 = vector pointing from r1 to r2, the two ends of the bondcharge.
! This gives us the distance dbc (or y value in the 2D grid).
            z = distance (r1, r2)
            ! unit vector in sigma direction.
            if (z .lt. 1.0d-05) then
              sighat(1) = 0.0d0
              sighat(2) = 0.0d0
              sighat(3) = 1.0d0
            else
              sighat = (r2 - r1)/z
            end if
            call epsilon_function (r2, sighat, eps)
            call Depsilon_2c (r1, r2, eps, deps)

! CALL DOSCENTROS AND GET rho_in FOR ONTOP CASE (i.e. OFF-SITE matrix elements)
! ****************************************************************************
! If r1 .ne. r2, then this is a case where the potential is located at one of
! the sites of a wavefunction (ontop case).
            if (iatom .eq. jatom .and. mbeta .eq. 0) then

! Do nothing here - this is the on-site case

            else

! Get the matrix from the data files - which is the matrix in molecular
! coordinates (stored in bcxcm). Rotate the matrix into crystal coordinates.
! The rotated  matrix elements are stored in bcxcx, where x means crytal
! coordinates.
              interaction = P_vxc_ontop
              in3 = in2
              allocate (bcxcm (norb_mu, norb_nu)); bcxcm = 0.0d0
              allocate (bcxcx (norb_mu, norb_nu)); bcxcx = 0.0d0
              allocate (dbcxcm (norb_mu, norb_nu)); dbcxcm = 0.0d0
              allocate (vdcxcm (3, norb_mu, norb_nu)); vdcxcm = 0.0d0
              allocate (vdbcxcx (3, norb_mu, norb_nu)); vdbcxcx = 0.0d0
              isubtype = 0
              call getDMEs_Fdata_2c (in1, in3, interaction, isubtype, z,     &
     &                               norb_mu, norb_nu, bcxcm, dbcxcm)

! ****************************************************************************
!
! FORCES
! ****************************************************************************
! dtm is the "scalar" derivative of the matrix; vdtm is the "vector" derivative
! of the matrix in molecular coordinates.  When we are done, we get: vdtx as
! the vector derivative of the matrix in crystal coordinates.

! As long as epsilon is called with sighat in the second "spot" as
! call epsilon_function (R1, sighat, spe), then eps(ix,3) = eta(ix).
              eta(:) = eps(:,3)

! Note that if we are calculating the on-site matrix elements, then the
! derivatives should be exactly zero.  This is what Otto referred to as the
! ferbie test.  For example, for the on-site overlap, we get an identity
! matrix, thus surely we should never use a "derivative of the unit matrix".

! Note the minus sign. d/dr1 = - eta * d/dd.
              do inu = 1, norb_nu
                do imu = 1, norb_mu
                    vdcxcm(:,imu,inu) = - eta(:)*dbcxcm(imu,inu)
                end do
              end do

! Drotate then puts the vectors in coordinates alone the bond-charge.
              call Drotate (in1, in2, eps, deps, norb_mu, norb_nu,           &
     &                      bcxcm, vdcxcm, vdbcxcx)

              pvxc_bond_neighbors%Dblock = vdbcxcx
              deallocate (bcxcm, bcxcx)
              deallocate (dbcxcm, vdcxcm)
              deallocate (vdbcxcx)
            end if ! different atoms loop
          end do ! end loop over neighbors
        end do ! end loop over atoms

! Deallocate Arrays
! ===========================================================================
! None

! Format Statements
! ===========================================================================
! None

! End Subroutine
! ===========================================================================
        return
        end subroutine Dassemble_vxc_bond


! ===========================================================================
! Dassemble_vxc_3c
! ===========================================================================
! Subroutine Description
! ===========================================================================
!> This routine calculates/assembles the SNXC 2 center part, the OLSXC 2
!! center part, and also the d (< mu_i| V_xc (rho) | nu_i>)/dR called
!! "on-site" in the notes.
!!
!!       rho_in (input density) --> (vxc_SN)
!!
!! Definition of rho_in and rho_local:
!!       rho_bond (mu,nu) = < mu | rho_i | nu >
!!         if mu and nu are in the same atom "i" : onsite case
!!       rho_bond (mu,nu) = < mu | rho_i + rho_j | nu >
!!         if mu and nu are in different atoms "i" and "j" : atom case
!!       rho_in = sum of onsite rho_bond values
!
! ===========================================================================
! Code written by:
!> @author Daniel G. Trabada
!! @author Jose Ortega (JOM)
! Departamento de Fisica Teorica de la Materia Condensada
! Universidad Autonoma de Madrid
! ===========================================================================
!
! Program Declaration
! ===========================================================================
        subroutine Dassemble_vxc_3c (s)
        implicit none

! Argument Declaration and Description
! ===========================================================================
        type(T_structure), target :: s           !< the structure to be used.

! Parameters and Data Declaration
! ===========================================================================
! None

! Variable Declaration and Description
! ===========================================================================
        integer iatom, ineigh, mneigh      !< counter over atoms and neighbors
        integer in1, in2, in3              !< species numbers
        integer jatom, ialpha              !< jatom is the neighbor of iatom ialpha is the third atom for 3c
        integer logfile                    !< writing to which unit
        integer ibeta                      !< matom is the self-interaction atom
        integer jbeta                      !< the cell containing neighbor of iatom
        integer isubtype                   !< which interaction and subtype
        integer imu, inu                   !< counter over orbitals
        integer issh, jssh                 !< counter over shells
        integer norb_mu, norb_nu           !< size of the block for the pair
        integer iindex

        ! inputs for xc functional
        real prho_in_shell                 !< temporary storage
        real prho_in                       !< temporary storage
        real dexc_in                       !< 1st derivative of xc energy
        real d2exc_in                      !< 2nd derivative of xc energy
        real dmuxc_in                      !< 1st derivative of xc potential
        real exc_in                        !< xc energy
        real muxc_in                       !< xc potential_
        real d2muxc_in                     !< 2nd derivative of xc potential

        real, dimension (3) :: r1, r2, r3!, r12     !< positions of iatom and jatom ialpha

        type(T_Fdata_cell_3c), pointer :: pFdata_cell
        type(T_Fdata_bundle_3c), pointer :: pFdata_bundle

        type(T_assemble_block), pointer :: pvxc_SN_neighbors
        type(T_assemble_neighbors), pointer :: pvxc_SN

! Allocate Arrays
! ===========================================================================
! None

! Procedure
! ===========================================================================
! Initialize logfile
        logfile = s%logfile

! Procedure
! ===========================================================================
! ***************************************************************************
!
!                       O F F  -  S I T E    P I E C E(off diagonal terms)
!
! ***************************************************************************
! Loop over the atoms in the central cell.
        do ialpha = 1, s%natoms
          in3 = s%atom(ialpha)%imass
          r3 = s%atom(ialpha)%ratom

! Loop over the neighbors of each iatom.
          do ineigh = 1, s%neighbors(ialpha)%ncommon  ! <==== loop over i's neighbors
            mneigh = s%neighbors(ialpha)%neigh_common(ineigh)
            if (mneigh .ne. 0) then
              iatom = s%neighbors(ialpha)%iatom_common_j(ineigh)
              ibeta = s%neighbors(ialpha)%iatom_common_b(ineigh)
              r1 = s%atom(iatom)%ratom + s%xl(ibeta)%a
              in1 = s%atom(iatom)%imass
              norb_mu = species(in1)%norb_max


              jatom = s%neighbors(ialpha)%jatom_common_j(ineigh)
              jbeta = s%neighbors(ialpha)%jatom_common_b(ineigh)
              r2 = s%atom(jatom)%ratom + s%xl(jbeta)%a
              in2 = s%atom(jatom)%imass
              norb_nu = species(in2)%norb_max

              ! cut some lengthy notation
              pvxc_SN=>s%vxc(iatom); pvxc_SN_neighbors=>pvxc_SN%neighbors(mneigh)

              ! cut some more lengthy notation
              allocate (pvxc_SN_neighbors%Dblocka(3, norb_mu, norb_nu))
              allocate (pvxc_SN_neighbors%Dblockb(3, norb_mu, norb_nu))
              allocate (pvxc_SN_neighbors%Dblockc(3, norb_mu, norb_nu))
              pvxc_SN_neighbors%Dblocka = 0.0d0
              pvxc_SN_neighbors%Dblockb = 0.0d0
              pvxc_SN_neighbors%Dblockc = 0.0d0

              do issh = 1, species(in1)%nssh
                do jssh = 1, species(in2)%nssh
                 do isubtype = 1, species(in3)%nssh
                  pFdata_bundle => Fdata_bundle_3c(in1, in2, in3)
                  pFdata_cell =>                                             &
     &              pFdata_bundle%Fdata_cell_3c(pFdata_bundle%index_3c(P_rho_3c,isubtype,1))

                  do iindex = 1, pFdata_cell%nME
                    imu = pFdata_cell%mu_3c(iindex)
                    inu = pFdata_cell%nu_3c(iindex)

! Call lda-function with rho_in_weighted to get the coefficients for vxc expancion
                   prho_in_shell =                                           &
     &               s%rho_in_weighted(iatom)%neighbors(mneigh)%block(issh,jssh)
                   call lda_ceperley_alder (prho_in_shell, exc_in, muxc_in,  &
     &                                      dexc_in, d2exc_in, dmuxc_in, d2muxc_in)

                   prho_in = s%rho_in(iatom)%neighbors(mneigh)%block(imu,inu)

                   pvxc_SN_neighbors%Dblocka(:,imu,inu) =                    &
     &               d2muxc_in*prho_in*s%rho_in_weighted(iatom)%neighbors(mneigh)%Dblocka(:,issh,jssh) &
     &               + dmuxc_in*s%rho_in(iatom)%neighbors(mneigh)%Dblocka(:,imu,inu)

                   pvxc_SN_neighbors%Dblockb(:,imu,inu) =                    &
     &               d2muxc_in*prho_in*s%rho_in_weighted(iatom)%neighbors(mneigh)%Dblockb(:,issh,jssh) &
     &               + dmuxc_in*s%rho_in(iatom)%neighbors(mneigh)%Dblockb(:,imu,inu)

                   pvxc_SN_neighbors%Dblockc(:,imu,inu)=                     &
     &               d2muxc_in*prho_in*s%rho_in_weighted(iatom)%neighbors(mneigh)%Dblockc(:,issh,jssh) &
     &               + dmuxc_in*s%rho_in(iatom)%neighbors(mneigh)%Dblockc(:,imu,inu)
                  end do ! iindex = 1, pFdata_cell%nME
                 end do ! isubtype = 1, species(in3)%nssh
                end do ! end loop jssh = 1, species(in2)%nssh
              end do ! end loop issh = 1, species(in1)%nssh
            end if ! if (mneigh .ne. 0)
          end do ! end loop over the neighbors
        end do ! end loop over the atoms

! Deallocate Arrays
! ===========================================================================
! None

! Format Statements
! ===========================================================================
! None

! End Subroutine
! ===========================================================================
        return
        end subroutine Dassemble_vxc_3c


! End Module
! ===========================================================================
        end module M_Dassemble_vxc
