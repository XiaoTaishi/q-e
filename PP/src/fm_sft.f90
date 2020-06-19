MODULE pp_fm_sft
CONTAINS
!-----------------------------------------------------------------------
SUBROUTINE calc_fm_sft ( plot_files )
  !-----------------------------------------------------------------------
  USE kinds,             ONLY : DP
  USE ener,              ONLY : ef, ehart
  USE gvect
  USE fft_base,          ONLY : dfftp
  USE klist,             ONLY : two_fermi_energies, degauss, nks, nkstot, xk
  USE io_files,          ONLY : tmp_dir, prefix
  USE io_global,         ONLY : ionode, ionode_id
  USE noncollin_module,  ONLY : i_cons, noncolin
  USE mp,                ONLY : mp_bcast
  USE mp_images,         ONLY : intra_image_comm
  USE constants,         ONLY : rytoev, BOHR_RADIUS_SI
  USE parameters,        ONLY : npk
  USE io_global,         ONLY : stdout
  USE cell_base,         ONLY : at, bg, omega, alat, celldm, ibrav
  USE ions_base,         ONLY : nat, ntyp => nsp, ityp, tau, zv, atm
  USE run_info,          ONLY : title
  USE scatter_mod,       ONLY : gather_grid
  USE gvecs,             ONLY : dual
  USE gvecw,             ONLY : ecutwfc
  !
  IMPLICIT NONE

#if defined(__MPI)
  ! auxiliary vector (parallel case)
  REAL(DP), ALLOCATABLE :: raux1 (:)
#endif
  ! auxiliary vector
  REAL(DP), ALLOCATABLE :: raux (:), fs(:)
  !
  CHARACTER(LEN=256), EXTERNAL :: trimcheck
  !
  CHARACTER(len=256), DIMENSION(:), ALLOCATABLE, INTENT(out) :: plot_files

  INTEGER :: ios

  REAL(DP) :: electemp
  REAL(DP) :: emin, emax, delta_e_ry
  REAL(DP) :: degauss_ldos, delta_e, wcutthr
  REAL(DP) :: dfdd, d_e
  CHARACTER(len=256) :: filplot
  INTEGER :: nplots
  INTEGER :: iplot

  ! directory for temporary files
  CHARACTER( len=256 ) :: outdir

  NAMELIST / inputpp / outdir, prefix, wcutthr, delta_e, degauss_ldos, filplot, electemp
  !
  !   set default values for variables in namelist
  !
  prefix = 'pwscf'
  CALL get_environment_variable( 'ESPRESSO_TMPDIR', outdir )
  IF ( trim( outdir ) == ' ' ) outdir = './'
  filplot = 'tmp.fs'
  wcutthr=1.0d0
  delta_e=0.01d0
  degauss_ldos=-999.0d0
  electemp=0.1d0
  !
  ios = 0

  IF ( ionode )  THEN
     ! reading the namelist inputpp
     READ ( 5, inputpp, iostat = ios )
     tmp_dir = trimcheck ( outdir )
     !
  END IF

  CALL mp_bcast ( ios, ionode_id, intra_image_comm )
  !
  IF ( ios /= 0 ) CALL errore ( 'fm_sft', 'reading inputpp namelist', abs( ios ) )
  !
  ! ... Broadcast variables
  !
  CALL mp_bcast( tmp_dir, ionode_id, intra_image_comm )
  CALL mp_bcast( prefix, ionode_id, intra_image_comm )
  CALL mp_bcast( degauss_ldos, ionode_id, intra_image_comm )
  CALL mp_bcast( delta_e, ionode_id, intra_image_comm )
  CALL mp_bcast( filplot, ionode_id, intra_image_comm )

  ! get wfc
  CALL read_file ( )
  CALL openfil_pp ( )

  IF ( two_fermi_energies .or. i_cons /= 0 ) &
     CALL errore('postproc',&
     'Post-processing with constrained magnetization is not available yet',1)
  ! switch from eV to Ry
  delta_e_ry = delta_e / rytoev
  emin = ef - wcutthr / rytoev
  emax = ef + wcutthr / rytoev
  electemp = electemp / rytoev

  IF ( degauss_ldos == -999.0d0 ) THEN
    WRITE( stdout, &
        '(/5x,"degauss_ldos not set, defaults to degauss = ",f6.4, " eV")') &
       degauss * rytoev
    degauss_ldos = degauss * rytoev
  END IF

  WRITE( stdout, '(/5x,"+++++++Special note: the unit of the output data is eV/\AA^3+++++++")' )

  nplots = 2 * wcutthr / delta_e + 1
  WRITE( stdout, '(/5x,"total ",i3," energy states will be calculated")' ) nplots

  ALLOCATE( plot_files( 1 ) )
  plot_files( 1 ) = filplot

  ! Local density of states on energy grid of spacing delta_e within [emin, emax]
  WRITE ( title, '(" Fermi energy = ",f8.4," eV, ", "electron temperature = ",f8.4," eV")' ) &
            ef * rytoev, electemp * rytoev
  !
  ALLOCATE ( fs( dfftp%nnr ) )
  ! initialize the Fermi softness vector
  fs(:) = 0.d0
  DO iplot = 1, nplots
    WRITE( stdout, '(/5x,"Energy =", f10.5, " eV, num =", i4)' ) &
        emin * rytoev, iplot
    ALLOCATE ( raux( dfftp%nnr ) )
     !
    IF ( noncolin ) CALL errore( 'punch_plot','not implemented yet',1 )
    !
    d_e = ( ( emin - ef ) / electemp ) ** 2.0d0
    IF ( d_e .le. 36.0 ) THEN
      ! calculate the 1st derivative of Fermi-Dirac distribution
      dfdd = 1.0d0 / ( 2.0d0 + exp ( - d_e ) + exp ( + d_e ) )
      ! The local density of states at emin, with broadening emax
      CALL local_dos(1, 0, 0, 0, 0, emin, degauss, raux)
      ! sum all the contributions to Fermi softness
      fs( : ) = fs( : ) + raux( : ) * dfdd
    END IF
     !
    emin = emin + delta_e_ry
    DEALLOCATE ( raux )
  END DO
  fs( : ) = fs( : ) * delta_e_ry / electemp / (BOHR_RADIUS_SI ** 3.0d0 * 10.0d0 ** 30.0d0) / rytoev * 1000.0d0
  ! writing data to file
  CALL plot_io (filplot, title,  dfftp%nr1x,  dfftp%nr2x,  dfftp%nr3x,   &
        dfftp%nr1,  dfftp%nr2,  dfftp%nr3, nat, ntyp, ibrav, celldm, at, &
        gcutm, dual, ecutwfc, 3, atm, ityp, zv, tau, fs, + 1)
  DEALLOCATE ( fs )

END SUBROUTINE calc_fm_sft

END MODULE pp_fm_sft

PROGRAM fm_sft

  USE io_global,          ONLY : ionode
  USE mp_global,          ONLY : mp_startup
  USE environment,        ONLY : environment_start,  environment_end
  USE chdens_module,      ONLY : chdens
  USE pp_fm_sft,          ONLY : calc_fm_sft

  !
  IMPLICIT NONE
  !
  !CHARACTER(len=256) :: filplot
  CHARACTER(len=256), DIMENSION( : ), ALLOCATABLE :: plot_files
  !INTEGER :: plot_num
  !
  ! initialise environment
  !
#if defined(__MPI)
  CALL mp_startup ( )
#endif
  CALL environment_start ( 'Fermi-softness' )
  !
  IF ( ionode )  CALL input_from_file ( )
  !
  CALL calc_fm_sft ( plot_files )
  !
  CALL chdens ( plot_files, 3 )
  !
  CALL environment_end ( 'Fermi-softness' )
  !
  CALL stop_pp( )
  !
END PROGRAM fm_sft
