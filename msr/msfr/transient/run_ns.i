################################################################################
## Molten Salt Fast Reactor - Euratom EVOL + Rosatom MARS Design              ##
## Transient 3D thermal hydraulics model                                      ##
## Laminar flow, addition of turbulence is WIP                                ##
################################################################################

# This simulation restarts from the steady state multiphysics coupled
# calculation Exodus output for the Pronghorn input. This can be re-generated
# in that folder by running run_neutronics.i with Griffin and Pronghorn
# coupled.

# Material properties
rho = 4284  # density [kg / m^3]  (@1000K)
cp = 1594  # specific heat capacity [J / kg / K]
drho_dT = 0.882  # derivative of density w.r.t. temperature [kg / m^3 / K]
mu = 0.0166 # viscosity [Pa s]
k = 1.7 # thermal conductivity [W / m / K]
# https://www.researchgate.net/publication/337161399_Development_of_a_control-\
# oriented_power_plant_simulator_for_the_molten_salt_fast_reactor/fulltext/5dc9\
# 5c9da6fdcc57503eec39/Development-of-a-control-oriented-power-plant-simulator-\
# for-the-molten-salt-fast-reactor.pdf
von_karman_const = 0.41

# Turbulent properties
Pr_t = 0.9 # turbulent Prandtl number
Sc_t = 1   # turbulent Schmidt number

# Derived material properties
alpha = ${fparse drho_dT / rho}  # thermal expansion coefficient

# Operating parameters
T_HX = 873.15 # heat exchanger temperature [K]

# Mass flow rate tuning, for heat exchanger pressure and temperature drop
friction = 4e3  # [kg / m^4]
pump_force = -20000. # [N / m^3]

# Delayed neutron precursor parameters. Lambda values are decay constants in
# [1 / s]. Beta values are production fractions.
lambda1 = 0.0133104
lambda2 = 0.0305427
lambda3 = 0.115179
lambda4 = 0.301152
lambda5 = 0.879376
lambda6 = 2.91303
beta1 = 8.42817e-05
beta2 = 0.000684616
beta3 = 0.000479796
beta4 = 0.00103883
beta5 = 0.000549185
beta6 = 0.000184087

################################################################################
# GEOMETRY
################################################################################

[Mesh]
  [restart]
    type = FileMeshGenerator
    use_for_exodus_restart = true
    file = '../steady/restart/run_ns_coupled_restart.e'
  []
[]

[Problem]
  coord_type = 'RZ'
  rz_coord_axis = Y
[]

################################################################################
# EQUATIONS: VARIABLES, KERNELS, BOUNDARY CONDITIONS
################################################################################

[Modules]
  [NavierStokesFV]
    # General parameters
    compressibility = 'incompressible'
    add_energy_equation = true
    boussinesq_approximation = true

    # Variables, defined below for the Exodus restart
    velocity_variable = 'vel_x vel_y'
    pressure_variable = 'pressure'
    fluid_temperature_variable = 'T_fluid'

    # Material properties
    density = ${rho}
    dynamic_viscosity = ${mu}
    thermal_conductivity = ${k}
    specific_heat = 'cp'
    thermal_expansion = ${alpha}

    # Boussinesq parameters
    gravity = '0 -9.81 0'
    ref_temperature = ${T_HX}

    # Boundary conditions
    wall_boundaries = 'shield_wall reflector_wall fluid_symmetry'
    momentum_wall_types = 'wallfunction wallfunction symmetry'
    energy_wall_types = 'heatflux heatflux heatflux'
    energy_wall_function = '0 0 0'

    # Pressure pin for incompressible flow
    pin_pressure = true
    pinned_pressure_type = average
    pinned_pressure_value = 1e5

    # Turbulence parameters
    turbulence_handling = 'mixing-length'
    turbulent_prandtl = ${Pr_t}
    von_karman_const = ${von_karman_const}
    mixing_length_delta = 0.1
    mixing_length_walls = 'shield_wall reflector_wall'
    mixing_length_aux_execute_on = 'initial'

    # Numerical scheme
    momentum_advection_interpolation = 'upwind'
    mass_advection_interpolation = 'upwind'
    energy_advection_interpolation = 'upwind'
    passive_scalar_advection_interpolation = 'upwind'

    # Heat source
    external_heat_source = power_density

    # Precursor advection, diffusion and source term
    passive_scalar_names = 'c1 c2 c3 c4 c5 c6'
    passive_scalar_schmidt_number = '${Sc_t} ${Sc_t} ${Sc_t} ${Sc_t} ${Sc_t} ${Sc_t}'
    passive_scalar_coupled_source = 'fission_source fission_source fission_source
                                     fission_source fission_source fission_source'
    passive_scalar_coupled_source_coeff = '${beta1} ${beta2} ${beta3} ${beta4} ${beta5} ${beta6}'

    # Heat exchanger
    friction_blocks = 'hx'
    friction_types = 'FORCHHEIMER'
    friction_coeffs = ${friction}
    ambient_convection_blocks = 'hx'
    ambient_convection_alpha = ${fparse 600 * 20e3} # HX specifications
    ambient_temperature = ${T_HX}
  []
[]

[Variables]
  [vel_x]
    type = INSFVVelocityVariable
    block = 'fuel pump hx'
    initial_from_file_var = vel_x
  []
  [vel_y]
    type = INSFVVelocityVariable
    block = 'fuel pump hx'
    initial_from_file_var = vel_y
  []
  [pressure]
    type = INSFVPressureVariable
    block = 'fuel pump hx'
    initial_from_file_var = pressure
  []
  [T_fluid]
    type = INSFVEnergyVariable
    block = 'fuel pump hx'
    initial_condition = ${T_HX}
    initial_from_file_var = T_fluid
  []

  [c1]
    type = MooseVariableFVReal
    block = 'fuel pump hx'
    initial_from_file_var = c1
  []
  [c2]
    type = MooseVariableFVReal
    block = 'fuel pump hx'
    initial_from_file_var = c2
  []
  [c3]
    type = MooseVariableFVReal
    block = 'fuel pump hx'
    initial_from_file_var = c3
  []
  [c4]
    type = MooseVariableFVReal
    block = 'fuel pump hx'
    initial_from_file_var = c4
  []
  [c5]
    type = MooseVariableFVReal
    block = 'fuel pump hx'
    initial_from_file_var = c5
  []
  [c6]
    type = MooseVariableFVReal
    block = 'fuel pump hx'
    initial_from_file_var = c6
  []
[]

[AuxVariables]
  [power_density]
    type = MooseVariableFVReal
    block = 'fuel pump hx'
    # Power density is re-initalized by a transfer from neutronics
    [InitialCondition]
      type = FunctionIC
      function = 'cosine_guess'
      scaling_factor = ${fparse 3e9/2.81543}
    []
  []
  [fission_source]
    type = MooseVariableFVReal
    # Fission source is re-initalized by a transfer from neutronics
    [InitialCondition]
      type = FunctionIC
      function = 'cosine_guess'
      scaling_factor = ${fparse 6.303329e+01/2.81543}
    []
    block = 'fuel pump hx'
  []
[]

[Functions]
  # Guess to have a 3D power distribution
  [cosine_guess]
    type = ParsedFunction
    value = 'max(0, cos(x*pi/2/1.2))*max(0, cos(y*pi/2/1.1))'
  []
[]

[FVKernels]
  [pump]
    type = INSFVBodyForce
    variable = vel_y
    functor = ${pump_force}
    block = 'pump'
    momentum_component = 'y'
    rhie_chow_user_object = 'ins_rhie_chow_interpolator'
  []

  [c1_decay]
    type = FVReaction
    variable = c1
    rate = ${lambda1}
    block = 'fuel pump hx'
  []
  [c2_decay]
    type = FVReaction
    variable = c2
    rate = ${lambda2}
    block = 'fuel pump hx'
  []
  [c3_decay]
    type = FVReaction
    variable = c3
    rate = ${lambda3}
    block = 'fuel pump hx'
  []
  [c4_decay]
    type = FVReaction
    variable = c4
    rate = ${lambda4}
    block = 'fuel pump hx'
  []
  [c5_decay]
    type = FVReaction
    variable = c5
    rate = ${lambda5}
    block = 'fuel pump hx'
  []
  [c6_decay]
    type = FVReaction
    variable = c6
    rate = ${lambda6}
    block = 'fuel pump hx'
  []
[]

################################################################################
# MATERIALS
################################################################################

[Materials]
  # Most of these constants could be specified directly to the action
  [mu]
    type = ADGenericFunctorMaterial
    prop_names = 'mu'
    prop_values = '${mu}'
    block = 'fuel pump hx'
  []
  # [not_used]
  #   type = ADGenericFunctorMaterial
  #   prop_names = 'not_used'
  #   prop_values = 0
  #   block = 'shield reflector'
  # []
  [cp]
    type = ADGenericFunctorMaterial
    prop_names = 'cp dcp_dt'
    prop_values = '${cp} 0'
    block = 'fuel pump hx'
  []
[]

################################################################################
# PUMP COASTDOWN PARAMETERS
################################################################################

[Functions]
  [pump_fun]
    type = PiecewiseConstant
    xy_data = '0.0 1
               4.0 0.5'
    direction = 'left'
  []
[]

[Controls]
  [pump_control]
    type = RealFunctionControl
    parameter = 'FVKernels/pump/scaling_factor'
    function = 'pump_fun'
    execute_on = 'initial timestep_begin'
  []
[]

################################################################################
# EXECUTION / SOLVE
################################################################################

[Executioner]
  type = Transient

  # Time stepping parameters
  # The time step is imposed by the neutronics app
  start_time = 0.0
  end_time = 1e10
  dt = 1e10

  # Solver parameters
  solve_type = 'NEWTON'
  petsc_options_iname = '-pc_type -pc_factor_shift_type -ksp_gmres_restart'
  petsc_options_value = 'lu NONZERO 50'
  line_search = 'none'

  nl_rel_tol = 1e-9
  nl_abs_tol = 2e-8
  nl_max_its = 15
  l_max_its = 50

  automatic_scaling = true
  # resid_vs_jac_scaling_param = 1
[]

################################################################################
# SIMULATION OUTPUTS
################################################################################

[Outputs]
  exodus = true
  csv = true
  hide = 'flow_hx_bot flow_hx_top min_flow_T max_flow_T'
  # Reduce base output
  print_linear_converged_reason = false
  print_linear_residuals = false
  print_nonlinear_converged_reason = false
[]

[Postprocessors]
  [max_v]
    type = ElementExtremeValue
    variable = vel_x
    value_type = max
    block = 'fuel pump hx'
  []
  [mdot]
    type = InternalVolumetricFlowRate
    boundary = 'min_core_radius'
    vel_x = vel_x
    vel_y = vel_y
    advected_mat_prop = ${rho}
  []
  # TODO: weakly compressible, switch to mass flow rate
  [flow_hx_bot]
    type = InternalVolumetricFlowRate
    boundary = 'hx_bot'
    vel_x = vel_x
    vel_y = vel_y
  []
  [flow_hx_top]
    type = InternalVolumetricFlowRate
    boundary = 'hx_top'
    vel_x = vel_x
    vel_y = vel_y
  []
  [max_flow_T]
    type = InternalVolumetricFlowRate
    boundary = 'hx_top'
    vel_x = vel_x
    vel_y = vel_y
    advected_variable = 'T_fluid'
  []
  [min_flow_T]
    type = InternalVolumetricFlowRate
    boundary = 'hx_bot'
    vel_x = vel_x
    vel_y = vel_y
    advected_variable = 'T_fluid'
  []
  [dT]
    type = ParsedPostprocessor
    function = '-max_flow_T / flow_hx_bot + min_flow_T / flow_hx_top'
    pp_names = 'max_flow_T min_flow_T flow_hx_bot flow_hx_top'
  []
  [total_power]
    type = ElementIntegralVariablePostprocessor
    variable = power_density
    block = 'fuel pump hx'
  []
  [total_fission_source]
    type = ElementIntegralVariablePostprocessor
    variable = fission_source
    block = 'fuel pump hx'
  []
  [pump]
    type = FunctionValuePostprocessor
    function = 'pump_fun'
  []
[]
