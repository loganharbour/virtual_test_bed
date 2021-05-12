# ==============================================================================
# Model description
# ------------------------------------------------------------------------------
# Idaho Falls, INL, August 10, 2020
# Author(s): Dr. Guillaume Giudicelli, Dr. Paolo Balestra, Dr. April Novak
# ==============================================================================
# - Coupled fluid-solid thermal hydraulics model of the Mk1-FHR
# ==============================================================================
# - The Model has been built based on [1-2].
# ------------------------------------------------------------------------------
# [1] Multiscale Core Thermal Hydraulics Analysis of the Pebble Bed Fluoride
#     Salt Cooled High Temperature Reactor (PB-FHR), A. Novak et al.
# [2] Technical Description of the “Mark 1” Pebble-Bed Fluoride-Salt-Cooled
#     High-Temperature Reactor (PB-FHR) Power Plant, UC Berkeley report 14-002
# [3] Molten salts database for energy applications, Serrano-Lopez et al.
#     https://arxiv.org/pdf/1307.7343.pdf
# [4] Heat Transfer Salts for Nuclear Reactor Systems - chemistry control,
#     corrosion mitigation and modeling, CFP-10-100, Anderson et al.
#     https://neup.inl.gov/SiteAssets/Final%20%20Reports/FY%202010/
#     10-905%20NEUP%20Final%20Report.pdf
# ==============================================================================
# MODEL PARAMETERS
# ==============================================================================
# Problem Parameters -----------------------------------------------------------

blocks_fluid = '3 4'
blocks_solid = '1 2 5 6 7 8 9'

# Material compositions
UO2_phase_fraction           = 1.20427291e-01
buffer_phase_fraction        = 2.86014816e-01
ipyc_phase_fraction          = 1.59496539e-01
sic_phase_fraction           = 1.96561801e-01
opyc_phase_fraction          = 2.37499553e-01
TRISO_phase_fraction         = 3.09266232e-01
core_phase_fraction          = 5.12000000e-01
fuel_matrix_phase_fraction   = 3.01037037e-01
shell_phase_fraction         = 1.86962963e-01

# FLiBe properties
# fluid_mu = 7.5e-3  # Pa.s at 900K [3]
# k_fluid =  1.1     # suggested constant [3]
# cp_fluid = 2385    # suggested constant [3]
rho_fluid = 1970.0   # kg/m3 at 900K [3]
alpha_b = 2e-4       # /K from [4]

# Graphite properties
heat_capacity_multiplier = 1e0  # >1 gets faster to steady state
solid_rho = 1780.0
# solid_k = 26.0
solid_cp = ${fparse 1697.0*heat_capacity_multiplier}

# Computation parameters
velocity_interp_method = 'rc'
advected_interp_method = 'upwind'

# Core geometry
pebble_diameter  = 0.03
bed_porosity     = 0.4
IR_porosity      = 0
model_inlet_rin  = 0.45
model_inlet_rout = 0.8574
model_vol        = 10.4
model_inlet_area = ${fparse 3.14159265 * (model_inlet_rout * model_inlet_rout -
                                          model_inlet_rin * model_inlet_rin)}

# Operating parameters
mfr = 976.0            # kg/s, from [2]
total_power = 236.0e6  # W, from [2]
inlet_T_fluid = 873.15 # K, from [2]
inlet_vel_y = ${fparse mfr / model_inlet_area / rho_fluid}
power_density = ${fparse total_power / model_vol / 258 * 236}  # adjusted using power pp

# ==============================================================================
# GEOMETRY AND MESH
# ==============================================================================

[Mesh]
  # Mesh should be fairly orthogonal for finite volume fluid flow
  [fmg]
    type = FileMeshGenerator
    file = '../meshes/core_CFD_0.06.e'
    use_for_exodus_restart = true
  []
[]

[Problem]
  coord_type = RZ
[]

[GlobalParams]
  rho = ${rho_fluid}
  porosity = porosity
  pebble_diameter = ${pebble_diameter}
  fp = fp
  T_solid = temp_solid

  velocity_interp_method = ${velocity_interp_method}
  advected_interp_method = ${advected_interp_method}
[]

[Debug]
  # show_var_residual_norms = true
  # show_material_props = true
[]

# ==============================================================================
# VARIABLES AND KERNELS
# ==============================================================================
[Variables]
  [vel_x]
    type = PINSFVSuperficialVelocityVariable
    block = ${blocks_fluid}
    initial_condition = 1e-12
    # initial_from_file_var = 'vel_x'
    # initial_from_file_timestep = 'LATEST'
  []
  [vel_y]
    type = PINSFVSuperficialVelocityVariable
    block = ${blocks_fluid}
    initial_condition = ${inlet_vel_y}
    # initial_from_file_var = 'vel_y'
    # initial_from_file_timestep = 'LATEST'
  []
  [pressure]
    type = INSFVPressureVariable
    block = ${blocks_fluid}
    initial_condition = 1e5
    # initial_from_file_var = 'pressure'
    # initial_from_file_timestep = 'LATEST'
  []
  [temp_fluid]
    type = INSFVEnergyVariable
    block = ${blocks_fluid}
    initial_condition = 900
    # initial_from_file_var = 'temp_fluid'
    # initial_from_file_timestep = 'LATEST'
  []
  [temp_solid]
    order = CONSTANT
    family = MONOMIAL
    fv = true
    # initial_condition = 800.0
    # initial_from_file_var = 'temp_solid'
    # initial_from_file_timestep = 'LATEST'
  []
[]

[FVKernels]
  # Mass Equation.
  [mass]
    type = PINSFVMassAdvection
    variable = pressure
    vel = 'superficial_velocity'
    u = vel_x
    v = vel_y
    pressure = pressure
    mu = 'mu'
  []

  # Momentum x component equation.
  [vel_x_time]
    type = PINSFVMomentumTimeDerivative
    variable = vel_x
  []
  [vel_x_advection]
    type = PINSFVMomentumAdvection
    variable = vel_x
    advected_quantity = 'superficial_rho_u'
    vel = 'superficial_velocity'
    pressure = pressure
    u = vel_x
    v = vel_y
    mu = 'mu'
  []
  [vel_x_viscosity]
    type = PINSFVMomentumDiffusion
    variable = vel_x
    mu = 'mu'
  []
  [u_pressure]
    type = PINSFVMomentumPressure
    variable = vel_x
    p = pressure
    momentum_component = 'x'
  []
  [u_friction]
    type = PINSFVMomentumFriction
    variable = vel_x
    Darcy_name = 'Darcy_coefficient'
    Forchheimer_name = 'Forchheimer_coefficient'
    momentum_component = 'x'
  []

  # Momentum y component equation.
  [vel_y_time]
    type = PINSFVMomentumTimeDerivative
    variable = vel_y
  []
  [vel_y_advection]
    type = PINSFVMomentumAdvection
    variable = vel_y
    advected_quantity = 'superficial_rho_v'
    vel = 'superficial_velocity'
    pressure = pressure
    u = vel_x
    v = vel_y
    mu = 'mu'
  []
  [vel_y_viscosity]
    type = PINSFVMomentumDiffusion
    variable = vel_y
    mu = 'mu'
  []
  [v_pressure]
    type = PINSFVMomentumPressure
    variable = vel_y
    p = pressure
    momentum_component = 'y'
  []
  [v_friction]
    type = PINSFVMomentumFriction
    variable = vel_y
    Darcy_name = 'Darcy_coefficient'
    Forchheimer_name = 'Forchheimer_coefficient'
    momentum_component = 'y'
  []
  [gravity]
    type = PINSFVMomentumGravity
    variable = vel_y
    gravity = '0 -9.81 0'
    momentum_component = 'y'
  []
  [buoyancy_boussinesq]
    type = PINSFVMomentumBoussinesq
    variable = vel_y
    gravity = '0 -9.81 0'
    ref_temperature = ${inlet_T_fluid}
    temperature = 'temp_fluid'
    momentum_component = 'y'
    alpha_name = 'alpha_b'
  []

  # Fluid Energy equation.
  [temp_fluid_time]
    type = PINSFVEnergyTimeDerivative
    variable = temp_fluid
    cp_name = 'cp'
    is_solid = false
  []
  [temp_fluid_advection]
    type = PINSFVEnergyAdvection
    variable = temp_fluid
    vel = 'superficial_velocity'
    advected_quantity = 'rho_cp_temp'
    pressure = pressure
    u = vel_x
    v = vel_y
    mu = 'mu'
  []
  [temp_fluid_conduction]
    type = PINSFVEnergyEffectiveDiffusion
    variable = temp_fluid
    kappa = 'kappa'
  []
  [temp_solid_to_fluid]
    type = PINSFVEnergyConvection
    variable = temp_fluid
    temp_fluid = temp_fluid
    temp_solid = temp_solid
    is_solid = false
    h_solid_fluid = 'alpha'
  []
  # [temp_fluid_source]
  #   type = FVCoupledForce
  #   variable = temp_fluid'
  #   v = power_distribution
  #   block = '3'
  # []

  # Solid Energy equation.
  [temp_solid_time_core]
    type = PINSFVEnergyTimeDerivative
    variable = temp_solid
    cp_name = 'cp_s'
    rho = ${solid_rho} # FIXME
    is_solid = true
    block = ${blocks_fluid}
  []
  [temp_solid_time]
    type = INSFVEnergyTimeDerivative
    variable = temp_solid
    cp_name = 'cp_s'
    block = ${blocks_solid}
  []
  [temp_solid_conduction_core]
    type = FVDiffusion
    variable = temp_solid
    coeff = 'kappa_s'
    block = ${blocks_fluid}
    force_boundary_execution = true # to connect with the reflector
  []
  [temp_solid_conduction]
    type = FVDiffusion
    variable = temp_solid
    coeff = 'k_s'
    block = ${blocks_solid}
    # boundaries_to_not_force = 'bed_left bed_right'
  []
  [temp_solid_source]
    type = FVCoupledForce
    variable = temp_solid
    v = power_distribution
    block = '3'
  []
  [temp_fluid_to_solid]
    type = PINSFVEnergyConvection
    variable = temp_solid
    temp_fluid = 'temp_fluid'
    temp_solid = 'temp_solid'
    is_solid = true
    h_solid_fluid = 'alpha'
    block = ${blocks_fluid}
  []
[]

[FVInterfaceKernels]
  [diffusion_interface]
    type = FVOneVarDiffusionInterface
    boundary = 'bed_left'
    subdomain1 = '3 4'
    subdomain2 = '1 2 5'
    coeff1 = 'kappa_s'
    coeff2 = 'k_s'
    variable1 = 'temp_solid'
  []
[]

# ==============================================================================
# AUXVARIABLES AND AUXKERNELS
# ==============================================================================
[AuxVariables]
  [power_distribution]
    order = CONSTANT
    family = MONOMIAL
    fv = true
    block = '3'
    # initial_from_file_var = 'power_distribution'
    # initial_from_file_timestep = 'LATEST'
  []
  [porosity]
    family = MONOMIAL
    order = CONSTANT
    fv = true
    initial_condition = ${bed_porosity}
    block = '3 4'
  []
[]

# ==============================================================================
# INITIAL CONDITIONS AND FUNCTIONS
# ==============================================================================
[ICs]
  [pow_init1]
    type = FunctionIC
    variable = power_distribution
    function = ${power_density}
    block = '3'
  []
  [core_T]
    type = FunctionIC
    variable = temp_solid
    function = 800
    block = '1 2 3 4 5 6 7 8'
  []
  [bricks]
    type = FunctionIC
    variable = temp_solid
    function = 350
    block = '9'
  []
[]

[Functions]
  [mu_func]
    type = PiecewiseLinear
    x = '1 3 5 10'
    y = '1e3 1e2 1e1 1'
  []
[]

[Controls]
  [mu_control]
    type = RealFunctionControl
    parameter = 'Materials/fluidprops/mu_multiplier'
    function = 'mu_func'
    execute_on = 'initial timestep_begin'
  []
[]

# ==============================================================================
# BOUNDARY CONDITIONS
# ==============================================================================
[FVBCs]
  [inlet_vel_x]
    type = INSFVInletVelocityBC
    variable = vel_x
    function = 1e-12
    boundary = 'bed_horizontal_bottom'
  []
  [inlet_vel_y]
    type = INSFVInletVelocityBC
    variable = vel_y
    function = ${inlet_vel_y}
    boundary = 'bed_horizontal_bottom'
  []
  #TODO: Switch to a flux BC (eps * phi * T)
  [inlet_temp_fluid]
    type = FVDirichletBC
    variable = temp_fluid
    value = ${fparse inlet_T_fluid}
    boundary = 'bed_horizontal_bottom'
  []

  [free-slip-wall-x]
    type = INSFVNaturalFreeSlipBC
    boundary = 'bed_left bed_right'
    variable = vel_x
  []
  [free-slip-wall-y]
    type = INSFVNaturalFreeSlipBC
    boundary = 'bed_left bed_right'
    variable = vel_y
  []

  [outer]
    type = FVDirichletBC
    variable = temp_solid
    boundary = 'brick_surface'
    value = ${fparse 35 + 273.15}
  []

  [outlet_p]
    type = INSFVOutletPressureBC
    variable = pressure
    function = 2e5   # not too far from atm for matprop evaluations
    boundary = 'bed_horizontal_top'
  []
[]

# ==============================================================================
# FLUID PROPERTIES, MATERIALS AND USER OBJECTS
# ==============================================================================
[FluidProperties]
  [fp]
    type = FlibeFluidProperties
  []
[]

[Materials]
  [firebrick_properties]
    type = ADGenericConstantMaterial
    prop_names = 'rho_s         cp_s        k_s'
    prop_values = '${solid_rho} ${solid_cp} 0.26'
    block = '9'
  []

  # material properties
  [solid_fuel_pebbles]
    type = PronghornSolidMaterialPT
    solid = pebble
    block = '3'
  []
  [solid_blanket_pebbles]
    type = PronghornSolidMaterialPT
    solid = graphite
    block = '4'
  []
  [plenum_and_OR]
    type = PronghornSolidMaterialPT
    solid = graphite
    block = '5 7'
  []
  [IR]
    type = PronghornSolidMaterialPT
    solid = inner_reflector
    block = '1 2'
  []
  [barrel_and_vessel]
    type = PronghornSolidMaterialPT
    solid = stainless_steel
    block = '6 8'
  []

  # FLUID
  [ins_fv]
    type = INSFVPrimitiveSuperficialVarMaterial
    superficial_vel_x = 'vel_x'
    superficial_vel_y = 'vel_y'
    pressure = pressure
    T_fluid = 'temp_fluid'
    T_solid = 'temp_solid'
    block = ${blocks_fluid}
    p_constant = 1e5
    T_constant = 900
  []
  [alpha_boussinesq]
    type = ADGenericConstantMaterial
    prop_names = 'alpha_b'
    prop_values = '${alpha_b}'
    block = ${blocks_fluid}
  []
  [fluidprops]
    type = PronghornFluidProps
    block = ${blocks_fluid}
    mu_multiplier = 1e3
  []

  # closures in the pebble bed
  [alpha]
    type = WakaoPebbleBedHTC
    block = ${blocks_fluid}
  []
  [drag]
    type = ErgunDragCoefficients
    block = ${blocks_fluid}
  []
  [kappa]
    type = LinearPecletKappaFluid
    block = ${blocks_fluid}
  []
  [kappa_s]
    type = PebbleBedKappaSolid
    emissivity = 0.8
    Youngs_modulus = 9e9
    Poisson_ratio = 0.136
    wall_distance = wall_dist
    block = ${blocks_fluid}
    T_solid = temp_solid
    acceleration = '0 -9.81 0'
  []
[]

[UserObjects]
  [graphite]
    type = FunctionSolidProperties
    rho_s = 1780
    cp_s = ${fparse 1800.0 * heat_capacity_multiplier}
    k_s = 26.0
  []
  [pebble_graphite]
    type = FunctionSolidProperties
    rho_s = 1600.0
    cp_s = 1800.0
    k_s = 15.0
  []
  [pebble_core]
    type = FunctionSolidProperties
    rho_s = 1450.0
    cp_s = 1800.0
    k_s = 15.0
  []
  [UO2]
    type = FunctionSolidProperties
    rho_s = 11000.0
    cp_s = 400.0
    k_s = 3.5
  []
  [pyc]
    type = PyroliticGraphite # (constant)
  []
  [buffer]
    type = PorousGraphite # (constant)
  []
  [SiC]
    type = FunctionSolidProperties
    rho_s = 3180.0
    cp_s = 1300.0
    k_s = 13.9
  []
  [TRISO]
    type = CompositeSolidProperties
    materials = 'UO2 buffer pyc SiC pyc'
    fractions = '${UO2_phase_fraction} ${buffer_phase_fraction} ${ipyc_phase_fraction} '
                '${sic_phase_fraction} ${opyc_phase_fraction}'
  []
  [fuel_matrix]
    type = CompositeSolidProperties
    materials = 'TRISO pebble_graphite'
    fractions = '${TRISO_phase_fraction} ${fparse 1.0 - TRISO_phase_fraction}'
    k_mixing = 'chiew'
  []
  [pebble]
    type = CompositeSolidProperties
    materials = 'pebble_core fuel_matrix pebble_graphite'
    fractions = '${core_phase_fraction} ${fuel_matrix_phase_fraction} ${shell_phase_fraction}'
  []
  [stainless_steel]
    type = StainlessSteel
  []
  [solid_flibe]
    type = FunctionSolidProperties
    rho_s = 1986.62668
    cp_s = 2416.0
    k_s = 1.0665
  []
  [inner_reflector]
    type = CompositeSolidProperties
    materials = 'solid_flibe graphite'
    fractions = '${IR_porosity} ${fparse 1.0 - IR_porosity}'
  []
  [wall_dist]
    type = WallDistanceAngledCylindricalBed
    outer_radius_x = '0.8574 0.8574 1.25 1.25 0.89 0.89'
    outer_radius_y = '0.0 0.709 1.389 3.889 4.5125 5.3125'
    inner_radius_x = '0.45 0.45 0.35 0.35 0.71 0.71'
    inner_radius_y = '0.0 0.859 1.0322 3.889 4.5125 5.3125'
  []
[]

# ==============================================================================
# EXECUTION PARAMETERS
# ==============================================================================
[Executioner]
  type = Transient

  solve_type = 'NEWTON'
  petsc_options_iname = '-pc_type -sub_pc_type -sub_pc_factor_shift_type -ksp_gmres_restart'
  petsc_options_value = 'asm      lu           NONZERO                   200'
  line_search = 'none'

  # Iterations parameters
  l_max_its = 100
  l_tol     = 1e-8
  nl_max_its = 25
  nl_rel_tol = 5e-7
  nl_abs_tol = 2e-7

  # Automatic scaling
  automatic_scaling = true

  # Problem time parameters
  dtmin = 1
  dtmax = 2e4
  end_time = 1e6

  [TimeStepper]
    type = IterationAdaptiveDT
    dt                 = 1
    cutback_factor     = 0.5
    growth_factor      = 4.0
  []

  # Steady state detection.
  steady_state_detection = true
  steady_state_tolerance = 1e-8
  steady_state_start_time = 400
[]

# ==============================================================================
# MULTIAPPS FOR PEBBLE MODEL
# ==============================================================================
[MultiApps]
  [coarse_mesh]
    type = TransientMultiApp
    execute_on = 'TIMESTEP_END'
    input_files = 'ss3_coarse_pebble_mesh.i'
  []
[]

[Transfers]
  [fuel_matrix_heat_source]
    type = MultiAppProjectionTransfer
    direction = to_multiapp
    multi_app = coarse_mesh
    source_variable = power_distribution
    variable = power_distribution
  []
  [pebble_surface_temp]
    type = MultiAppProjectionTransfer
    direction = to_multiapp
    multi_app = coarse_mesh
    source_variable = temp_solid
    variable = temp_solid
  []
[]

# ==============================================================================
# POSTPROCESSORS DEBUG AND OUTPUTS
# ==============================================================================
[Postprocessors]
  # For future SAM coupling
  # [inlet_vel_y]
  #   type = Receiver
  #   default = ${inlet_vel_y}
  #   execute_on = INITIAL
  # []
  # [outlet_pressure]
  #   type = Receiver
  #   default = ${outlet_pressure}
  #   execute_on = INITIAL
  # []
  [max_Tf]
    type = ElementExtremeValue
    variable = temp_fluid
    block = ${blocks_fluid}
  []
  [max_vy]
    type = ElementExtremeValue
    variable = vel_y
    block = ${blocks_fluid}
  []
  [power]
    type = ElementIntegralVariablePostprocessor
    variable = power_distribution
    block = '3'
    execute_on = 'INITIAL TIMESTEP_BEGIN TRANSFER TIMESTEP_END'
  []
  [mass_flow_out]
    type = VolumetricFlowRate
    boundary = 'bed_horizontal_top'
    vel_x = 'vel_x'
    vel_y = 'vel_y'
    advected_variable = ${rho_fluid}
    execute_on = 'INITIAL TIMESTEP_END'
  []
  [T_flow_out]
    type = SideAverageValue
    boundary = 'bed_horizontal_top'
    variable = temp_fluid
    execute_on = 'INITIAL TIMESTEP_END'
  []
  [pressure_in]
    type = SideAverageValue
    boundary = 'bed_horizontal_bottom'
    variable = pressure
    execute_on = 'INITIAL TIMESTEP_END'
  []
  [heat_loss]
    type = ADSideFluxIntegral
    boundary = 'brick_surface'
    variable = temp_solid
    diffusivity = 'k_s'
    execute_on = 'INITIAL TIMESTEP_END'
  []
  [energy_in_neg]
    type = VolumetricFlowRate
    boundary = 'bed_horizontal_bottom'
    vel_x = 'vel_x'
    vel_y = 'vel_y'
    advected_mat_prop = 'rho_cp_temp'
  []
  [energy_in]
    type = ScalePostprocessor
    value = energy_in_neg
    scaling_factor = -1
  []
  [energy_out]
    type = VolumetricFlowRate
    boundary = 'bed_horizontal_top'
    vel_x = 'vel_x'
    vel_y = 'vel_y'
    advected_mat_prop = 'rho_cp_temp'
  []
  [core_balance]
    type = DifferencePostprocessor
    value1 = energy_out
    value2 = energy_in
  []
[]

[Outputs]
  csv = true
  hide = 'energy_in energy_in_neg energy_out'
  [Exodus]
    type = Exodus
    output_material_properties = true
  []
  [CheckPoint]
    type = Checkpoint
    num_files = 2
    execute_on = 'FINAL'
  []
[]
